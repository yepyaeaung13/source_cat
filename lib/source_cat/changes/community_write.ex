defmodule SourceCat.Changes.CommunityWrite do
  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      actor = context.actor
      kind = opts[:kind]

      if is_nil(actor) or (kind != :comment and is_nil(actor.id)) do
        Ash.Changeset.add_error(changeset,
          field: :body,
          message: "Sign in with a visitor account first."
        )
      else
        prepare(changeset, actor, kind)
      end
    end)
  end

  defp prepare(changeset, actor, :question) do
    if recent(SourceCat.Community.Question, actor.id) >= 3 do
      Ash.Changeset.add_error(changeset,
        field: :body,
        message: "Please wait a minute before asking another question."
      )
    else
      Ash.Changeset.force_change_attributes(changeset, %{user_id: actor.id, name: actor.name})
    end
  end

  defp prepare(changeset, actor, :bookmark) do
    post = Ash.Changeset.get_attribute(changeset, :post_id)

    case Ash.get(SourceCat.Content.Post, post, actor: nil) do
      {:ok, record} when not is_nil(record) ->
        Ash.Changeset.force_change_attribute(changeset, :user_id, actor.id)

      _ ->
        Ash.Changeset.add_error(changeset, field: :post_id, message: "Published post not found.")
    end
  end

  defp prepare(changeset, actor, :comment) do
    alias SourceCat.Community.Comment
    thread = Ash.Changeset.get_attribute(changeset, :thread_id) || ""
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id) || ""

    parent =
      if parent_id == "",
        do: nil,
        else: Ash.get!(Comment, parent_id, authorize?: false, not_found_error?: false)

    owner = thread_owner(thread)
    user_id = actor.id || "studio"

    cond do
      is_nil(owner) ->
        Ash.Changeset.add_error(changeset,
          field: :thread_id,
          message: "Published post or question not found."
        )

      parent_id != "" and (is_nil(parent) or parent.thread_id != thread) ->
        Ash.Changeset.add_error(changeset,
          field: :parent_id,
          message: "Reply target not found on this thread."
        )

      recent(Comment, user_id) >= 10 ->
        Ash.Changeset.add_error(changeset,
          field: :body,
          message: "Please wait a minute before posting again."
        )

      true ->
        root = if parent, do: parent.root_id, else: Ash.Changeset.get_attribute(changeset, :id)

        author? =
          if String.starts_with?(thread, "question:"), do: owner == actor.id, else: actor.admin

        name =
          if actor.admin and not String.starts_with?(thread, "question:"),
            do: owner,
            else: actor.name

        Ash.Changeset.force_change_attributes(changeset, %{
          root_id: root,
          user_id: user_id,
          name: name,
          role: if(author?, do: "author", else: "member")
        })
    end
  end

  def thread_owner("question:" <> id) do
    case Ash.get(SourceCat.Community.Question, id, actor: nil) do
      {:ok, q} when not is_nil(q) -> q.user_id
      _ -> nil
    end
  end

  def thread_owner(id) do
    case Ash.get(SourceCat.Content.Post, id, actor: nil) do
      {:ok, p} when not is_nil(p) -> p.creator || "SourceCat"
      _ -> nil
    end
  end

  defp recent(resource, id) do
    cutoff = DateTime.add(DateTime.utc_now(), -60, :second)

    resource
    |> Ash.Query.filter(user_id == ^id and inserted_at > ^cutoff)
    |> Ash.count!(authorize?: false)
  end
end
