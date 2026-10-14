defmodule SourceCatWeb.AccountController do
  use SourceCatWeb, :controller
  import SourceCatWeb.DataHelpers
  alias SourceCat.Accounts.Credentials
  alias SourceCatWeb.Plugs.CurrentActor

  def state(conn, _) do
    name = get_session(conn, :suggestion) || Credentials.fresh_name()
    conn = put_session(conn, :suggestion, name)

    json(conn, %{
      token: Plug.CSRFProtection.get_csrf_token(),
      suggestion: name,
      user:
        if(conn.assigns.current_user,
          do: %{name: conn.assigns.current_user.name, kind: "pin"},
          else: nil
        ),
      admin: admin?(conn) || false
    })
  end

  def rename(conn, _),
    do: conn |> put_session(:suggestion, Credentials.fresh_name()) |> state(%{})

  def signup(conn, params) do
    if conn.assigns.current_user do
      error(conn, 409, "You already have an account. Sign out to create another.")
    else
      key = "signup:" <> CurrentActor.ip_key(conn)

      cond do
        Credentials.blocked?([key]) ->
          error(conn, 429, "Too many new accounts. Try again in 15 minutes.")

        true ->
          Credentials.failed([key])

          case Credentials.signup(get_session(conn, :suggestion), params["secret"]) do
            {:ok, user} ->
              conn
              |> CurrentActor.sign_in(user.id, admin?(conn) || false)
              |> delete_session(:suggestion)
              |> state(%{})

            {:error, {code, message}} ->
              error(conn, code, message)

            {:error, _} ->
              error(conn, 409, "That name was just taken. Generate another and try again.")
          end
      end
    end
  end

  def login(conn, params) do
    case Credentials.login(params["name"] || "", params["secret"], CurrentActor.ip_key(conn)) do
      {:ok, user} -> conn |> CurrentActor.sign_in(user.id, admin?(conn) || false) |> state(%{})
      {:error, {code, message}} -> error(conn, code, message)
    end
  end

  def logout(conn, _) do
    conn =
      if admin?(conn),
        do: CurrentActor.sign_in(conn, nil, true),
        else:
          conn |> CurrentActor.revoke() |> configure_session(renew: true) |> CurrentActor.call([])

    state(conn, %{})
  end

  def credentials(conn, params) do
    case conn.assigns.current_user do
      nil ->
        error(conn, 401, "Sign in first.")

      user ->
        case Credentials.change_pin(
               user,
               params["current_secret"],
               params["secret"],
               CurrentActor.ip_key(conn)
             ) do
          {:ok, user} ->
            import Ecto.Query

            SourceCat.Repo.delete_all(
              from s in SourceCat.Accounts.Session, where: s.user_id == ^user.id
            )

            conn
            |> assign(:account_session, nil)
            |> CurrentActor.sign_in(user.id, admin?(conn) || false)
            |> state(%{})

          {:error, {code, message}} ->
            error(conn, code, message)

          {:error, e} ->
            ash_error(conn, e)
        end
    end
  end
end
