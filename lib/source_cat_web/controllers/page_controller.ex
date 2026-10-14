defmodule SourceCatWeb.PageController do
  use SourceCatWeb, :controller

  def index(conn, _params) do
    conn |> put_root_layout(html: {SourceCatWeb.Layouts, :spa_root}) |> render(:index)
  end

  def post(conn, %{"id" => id}) do
    case Ash.get(SourceCat.Content.Post, id, actor: nil) do
      {:ok, p} when not is_nil(p) -> conn |> assign(:page_title, p.title) |> index(%{})
      _ -> conn |> put_status(404) |> put_view(html: SourceCatWeb.ErrorHTML) |> render(:"404")
    end
  end

  def question(conn, %{"id" => id}) do
    case Ash.get(SourceCat.Community.Question, id, actor: nil) do
      {:ok, q} when not is_nil(q) -> conn |> assign(:page_title, q.title) |> index(%{})
      _ -> conn |> put_status(404) |> put_view(html: SourceCatWeb.ErrorHTML) |> render(:"404")
    end
  end
end
