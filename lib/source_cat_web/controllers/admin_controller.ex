defmodule SourceCatWeb.AdminController do
  use SourceCatWeb, :controller
  import SourceCatWeb.DataHelpers
  alias SourceCat.Content.Post
  alias SourceCat.Accounts.Credentials
  alias SourceCatWeb.Plugs.CurrentActor

  def login(conn, params) do
    key = "admin:" <> CurrentActor.ip_key(conn)
    expected = Application.get_env(:source_cat, :admin_password, "")
    supplied = params["password"] || ""

    cond do
      expected == "" ->
        error(conn, 503, "Set ADMIN_PASSWORD before using Creator Studio.")

      Credentials.blocked?([key]) ->
        error(conn, 429, "Too many attempts. Try again in 15 minutes.")

      Plug.Crypto.secure_compare(:crypto.hash(:sha256, supplied), :crypto.hash(:sha256, expected)) ->
        Credentials.clear([key])

        conn
        |> CurrentActor.sign_in(actor(conn) && actor(conn).id, true)
        |> json(%{message: "Signed in"})

      true ->
        Credentials.failed([key])
        error(conn, 401, "Incorrect password.")
    end
  end

  def logout(conn, _) do
    id = actor(conn) && actor(conn).id

    conn =
      if id,
        do: CurrentActor.sign_in(conn, id, false),
        else: conn |> CurrentActor.revoke() |> configure_session(renew: true)

    json(conn, %{message: "Signed out"})
  end

  def content(conn, _) do
    if admin?(conn) do
      Post
      |> Ash.Query.sort(inserted_at: :desc, id: :asc)
      |> Ash.read!(actor: actor(conn))
      |> Enum.map(&entry/1)
      |> then(&json(conn, &1))
    else
      error(conn, 401, "Please sign in.")
    end
  end

  def save(conn, params) do
    if admin?(conn) do
      id = String.trim(params["id"] || "")
      original = params["original_id"] || ""
      record = Ash.get!(Post, id, actor: actor(conn), not_found_error?: false)

      cond do
        original != "" and original != id ->
          error(conn, 422, "The URL slug cannot change after creation.")

        original != "" and is_nil(record) ->
          error(conn, 404, "Post not found.")

        original == "" and record ->
          error(conn, 409, "This URL slug already exists. Choose another.")

        true ->
          fields =
            Map.take(
              params,
              ~w(id kind title category excerpt body youtube creator thumbnail status date minutes)
            )

          changeset =
            if record,
              do: Ash.Changeset.for_update(record, :update, Map.delete(fields, "id")),
              else: Ash.Changeset.for_create(Post, :create, fields)

          result =
            if record,
              do: Ash.update(changeset, actor: actor(conn)),
              else: Ash.create(changeset, actor: actor(conn))

          case result do
            {:ok, p} -> json(conn, %{message: "Content saved.", post: entry(p)})
            {:error, e} -> ash_error(conn, e)
          end
      end
    else
      error(conn, 401, "Please sign in.")
    end
  end

  def delete(conn, %{"id" => id}) do
    if admin?(conn) do
      case Ash.get(Post, id, actor: actor(conn)) do
        {:ok, nil} ->
          error(conn, 404, "Post not found.")

        {:ok, p} ->
          case Ash.destroy(p, actor: actor(conn)) do
            :ok -> json(conn, %{message: "Content deleted."})
            {:error, e} -> ash_error(conn, e)
          end

        {:error, e} ->
          ash_error(conn, e)
      end
    else
      error(conn, 401, "Please sign in.")
    end
  end
end
