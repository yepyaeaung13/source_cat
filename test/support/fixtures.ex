defmodule SourceCat.Fixtures do
  alias SourceCat.Accounts.Credentials
  def admin, do: %{id: nil, name: "SourceCat", admin: true}

  def user(name \\ "Bright Mango") do
    {:ok, user} = Credentials.signup(name, "123456")
    user
  end

  def actor(user), do: %{id: user.id, name: user.name, admin: false}

  def post(attrs \\ %{}) do
    values =
      Map.merge(
        %{
          id: "test-post",
          kind: "article",
          title: "Learning Gleam",
          category: "Gleam",
          body: "<p>A useful programming article.</p>",
          creator: "SourceCat",
          status: "published"
        },
        attrs
      )

    SourceCat.Content.Post
    |> Ash.Changeset.for_create(:create, values)
    |> Ash.create!(actor: admin())
  end

  def question(actor, attrs \\ %{}) do
    values =
      Map.merge(
        %{
          title: "How do I learn Gleam?",
          topic: "Gleam",
          body: "I tried the tour and would love some advice."
        },
        attrs
      )

    SourceCat.Community.Question
    |> Ash.Changeset.for_create(:create, values, actor: actor)
    |> Ash.create!(actor: actor)
  end

  def comment(actor, thread, attrs \\ %{}) do
    SourceCat.Community.Comment
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{thread_id: thread, parent_id: "", body: "This was helpful!"}, attrs),
      actor: actor
    )
    |> Ash.create!(actor: actor)
  end
end
