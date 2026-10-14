defmodule SourceCat.Changes.DeletePost do
  use Ash.Resource.Change
  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      import Ecto.Query

      SourceCat.Repo.delete_all(
        from b in SourceCat.Community.Bookmark, where: b.post_id == ^record.id
      )

      SourceCat.Repo.delete_all(
        from c in SourceCat.Community.Comment, where: c.thread_id == ^record.id
      )

      {:ok, record}
    end)
  end
end
