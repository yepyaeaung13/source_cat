defmodule SourceCat.Checks.VisibleThread do
  use Ash.Policy.FilterCheck
  @impl true
  def describe(_), do: "belongs to a visible post or public question"
  @impl true
  def filter(actor, _context, _opts) do
    posts = Ash.read!(SourceCat.Content.Post, actor: actor) |> Enum.map(& &1.id)

    questions =
      Ash.read!(SourceCat.Community.Question, actor: actor) |> Enum.map(&("question:" <> &1.id))

    expr(thread_id in ^(posts ++ questions))
  end
end
