defmodule SourceCatWeb.ContentController do
  use SourceCatWeb, :controller
  import SourceCatWeb.DataHelpers
  alias SourceCat.Content.Post

  def posts(conn, _) do
    Post
    |> Ash.Query.sort(inserted_at: :desc, id: :asc)
    |> Ash.read!(actor: nil)
    |> Enum.map(&entry/1)
    |> then(&json(conn, &1))
  end

  def show(conn, %{"id" => id}) do
    case Ash.get(Post, id, actor: nil) do
      {:ok, nil} -> error(conn, 404, "Post not found.")
      {:ok, p} -> json(conn, entry(p))
      {:error, _} -> error(conn, 404, "Post not found.")
    end
  end

  def health(conn, _) do
    case Ecto.Adapters.SQL.query(SourceCat.Repo, "SELECT 1", []) do
      {:ok, _} -> json(conn, %{status: "ok"})
      _ -> conn |> put_status(503) |> json(%{status: "unavailable"})
    end
  end
end
