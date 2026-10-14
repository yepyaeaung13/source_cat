defmodule SourceCatWeb.CommunityController do
  use SourceCatWeb, :controller
  import SourceCatWeb.DataHelpers
  import Ecto.Query
  require Ash.Query
  alias SourceCat.Community.{Question, Comment, Bookmark}
  alias SourceCat.Changes.CommunityWrite

  def questions(conn, _) do
    counts =
      SourceCat.Repo.all(
        from c in Comment,
          where: not c.deleted and like(c.thread_id, "question:%"),
          group_by: c.thread_id,
          select: {c.thread_id, count(c.id)}
      )
      |> Map.new()

    Question
    |> Ash.Query.sort(inserted_at: :desc, id: :asc)
    |> Ash.read!(actor: nil)
    |> Enum.map(&question(&1, Map.get(counts, "question:" <> &1.id, 0)))
    |> then(&json(conn, &1))
  end

  def show(conn, %{"id" => id}) do
    case Ash.get(Question, id, actor: nil) do
      {:ok, q} when not is_nil(q) -> json(conn, question(q))
      _ -> error(conn, 404, "Question not found.")
    end
  end

  def create_question(conn, params) do
    if actor(conn) && actor(conn).id do
      fields =
        Map.take(params, ~w(title topic body)) |> Map.new(fn {k, v} -> {k, String.trim(v)} end)

      case Question
           |> Ash.Changeset.for_create(:create, fields, actor: actor(conn))
           |> Ash.create(actor: actor(conn)) do
        {:ok, q} ->
          conn
          |> put_status(201)
          |> json(%{url: "/community/thread/" <> q.id, question: question(q)})

        {:error, e} ->
          ash_error(conn, e)
      end
    else
      error(conn, 401, "Sign in to ask a question.")
    end
  end

  def comments(conn, params), do: list_comments(conn, params["id"], params)

  def question_comments(conn, params),
    do: list_comments(conn, "question:" <> params["id"], params)

  defp list_comments(conn, thread, params) do
    with owner when not is_nil(owner) <- CommunityWrite.thread_owner(thread),
         {:ok, page} <- page(params) do
      roots =
        SourceCat.Repo.all(
          from c in Comment,
            where: c.thread_id == ^thread and c.parent_id == "",
            order_by: [desc: c.inserted_at, asc: c.id],
            limit: 10,
            offset: ^((page - 1) * 10),
            select: c.id
        )

      comments =
        SourceCat.Repo.all(
          from c in Comment,
            where: c.thread_id == ^thread and c.root_id in ^roots,
            order_by: [asc: c.inserted_at, asc: c.id]
        )

      root_count =
        SourceCat.Repo.aggregate(
          from(c in Comment, where: c.thread_id == ^thread and c.parent_id == ""),
          :count
        )

      total =
        SourceCat.Repo.aggregate(
          from(c in Comment, where: c.thread_id == ^thread and not c.deleted),
          :count
        )

      json(conn, %{
        comments: Enum.map(comments, &comment(&1, actor(conn))),
        page: page,
        pages: max(1, ceil(root_count / 10)),
        roots: root_count,
        total: total
      })
    else
      nil -> error(conn, 404, "Thread not found.")
      _ -> error(conn, 422, "Invalid page.")
    end
  end

  def add(conn, params), do: add_comment(conn, params["id"], params)
  def answer(conn, params), do: add_comment(conn, "question:" <> params["id"], params)

  defp add_comment(conn, thread, params) do
    if actor(conn) do
      fields = %{
        thread_id: thread,
        parent_id: params["parent"] || "",
        body: String.trim(params["body"] || "")
      }

      case Comment
           |> Ash.Changeset.for_create(:create, fields, actor: actor(conn))
           |> Ash.create(actor: actor(conn)) do
        {:ok, c} ->
          conn
          |> put_status(201)
          |> json(%{message: "Comment posted.", comment: comment(c, actor(conn))})

        {:error, e} ->
          ash_error(conn, e)
      end
    else
      error(conn, 401, "Create an account or sign in to comment.")
    end
  end

  def delete(conn, %{"id" => id}) do
    case Ash.get(Comment, id, actor: actor(conn)) do
      {:ok, nil} ->
        error(conn, 404, "Comment not found.")

      {:ok, c} ->
        case c
             |> Ash.Changeset.for_update(:remove, %{}, actor: actor(conn))
             |> Ash.update(actor: actor(conn)) do
          {:ok, _} -> json(conn, %{message: "Comment removed. Replies are preserved."})
          {:error, e} -> ash_error(conn, e)
        end

      {:error, e} ->
        ash_error(conn, e)
    end
  end

  def bookmarks(conn, _) do
    if actor(conn) && actor(conn).id do
      Bookmark |> Ash.read!(actor: actor(conn)) |> Enum.map(& &1.post_id) |> then(&json(conn, &1))
    else
      error(conn, 401, "Sign in to see your saved posts.")
    end
  end

  def bookmark(conn, %{"id" => id} = params) do
    if actor(conn) && actor(conn).id do
      existing = Bookmark |> Ash.Query.filter(post_id == ^id) |> Ash.read_one!(actor: actor(conn))

      case params["saved"] do
        "yes" ->
          result =
            if existing,
              do: {:ok, existing},
              else:
                Bookmark
                |> Ash.Changeset.for_create(:create, %{post_id: id}, actor: actor(conn))
                |> Ash.create(actor: actor(conn))

          case result do
            {:ok, _} -> bookmarks(conn, %{})
            {:error, e} -> ash_error(conn, e)
          end

        "no" ->
          if existing, do: Ash.destroy!(existing, actor: actor(conn))
          bookmarks(conn, %{})

        _ ->
          error(conn, 422, "Choose whether to save or remove this post.")
      end
    else
      error(conn, 401, "Create an account or sign in to save posts.")
    end
  end
end
