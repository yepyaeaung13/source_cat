defmodule SourceCat.FeatureParityTest do
  use SourceCat.DataCase
  import SourceCat.Fixtures
  alias SourceCat.Content.Post
  alias SourceCat.Community.{Comment, Bookmark, Question}
  alias SourceCat.Accounts.Credentials

  test "guest queries cannot see drafts, and only Studio can write posts" do
    published = post()
    post(%{id: "draft-post", status: "draft"})
    assert Enum.map(Ash.read!(Post, actor: nil), & &1.id) == [published.id]
    assert Ash.get!(Post, "draft-post", actor: nil, not_found_error?: false) == nil
    assert length(Ash.read!(Post, actor: admin())) == 2

    assert {:error, %Ash.Error.Forbidden{}} =
             Post
             |> Ash.Changeset.for_create(:create, %{
               id: "guest-post",
               title: "Nope",
               category: "Gleam",
               body: "<p>Hello</p>"
             })
             |> Ash.create(actor: nil)
  end

  test "article HTML is sanitized server-side and slug is immutable" do
    p =
      post(%{
        body:
          "<h2>Hello</h2><p onclick='bad()'>Safe <strong>text</strong></p><script>alert(1)</script><a href='javascript:bad()'>unsafe</a>"
      })

    assert p.body =~ "<h2>Hello</h2>"
    refute p.body =~ "onclick"
    refute p.body =~ "<script"
    refute p.body =~ "javascript:"

    assert {:error, _} =
             p
             |> Ash.Changeset.for_update(:update, %{id: "renamed"})
             |> Ash.update(actor: admin())
  end

  test "post validation covers slug, type, video ID and safe images" do
    for attrs <- [
          %{id: "bad/slug"},
          %{kind: "unknown"},
          %{kind: "video", youtube: "bad"},
          %{thumbnail: "javascript:alert(1)"},
          %{body: ""}
        ] do
      assert {:error, _} =
               Post
               |> Ash.Changeset.for_create(
                 :create,
                 Map.merge(
                   %{id: "new", title: "A post", category: "Crash Course", body: "<p>Hello</p>"},
                   attrs
                 )
               )
               |> Ash.create(actor: admin())
    end

    p = post(%{kind: "video", youtube: "2WtPyqwTLKM", category: "Crash Course", body: ""})
    assert p.category == "Crash Course"
  end

  test "PIN accounts use short names and case-insensitive login, never expose hashes" do
    u = user()
    assert {:ok, logged} = Credentials.login("bright mango", "123456", "test-ip")
    assert logged.id == u.id
    assert Regex.match?(~r/^[A-Z][a-z]+ [A-Z][a-z]+$/, Credentials.fresh_name())
    assert {:error, {422, _}} = Credentials.signup("Sunny Apple", "password")
    assert {:error, {401, _}} = Credentials.login(u.name, "000000", "test-ip")
    assert {:error, _} = Credentials.signup("BRIGHT MANGO", "123456")

    refute :password_hash in Enum.map(
             Ash.Resource.Info.public_attributes(SourceCat.Accounts.User),
             & &1.name
           )
  end

  test "PIN login attempts are blocked persistently" do
    user()

    for _ <- 1..8,
        do: assert({:error, {401, _}} = Credentials.login("Bright Mango", "000000", "blocked-ip"))

    assert {:error, {429, _}} = Credentials.login("Bright Mango", "123456", "blocked-ip")
  end

  test "nested replies retain their root and cannot cross threads" do
    p = post()
    a = actor(user())
    b = actor(user("Calm Peach"))
    q = question(a)
    root = comment(a, p.id)
    reply = comment(b, p.id, %{parent_id: root.id})
    nested = comment(a, p.id, %{parent_id: reply.id})
    assert nested.root_id == root.id
    assert reply.role == "member"

    assert {:error, _} =
             Comment
             |> Ash.Changeset.for_create(
               :create,
               %{thread_id: "question:" <> q.id, parent_id: reply.id, body: "Wrong thread"},
               actor: a
             )
             |> Ash.create(actor: a)

    assert {:error, %Ash.Error.Forbidden{}} =
             root |> Ash.Changeset.for_update(:remove, %{}, actor: b) |> Ash.update(actor: b)

    deleted = root |> Ash.Changeset.for_update(:remove, %{}, actor: a) |> Ash.update!(actor: a)
    assert deleted.deleted and deleted.body == ""

    assert Ash.get!(Comment, nested.id, actor: nil, not_found_error?: false).body ==
             "This was helpful!"
  end

  test "post Studio replies and question owner replies have author badges" do
    p = post()
    a = actor(user())
    q = question(a)
    assert comment(admin(), p.id).role == "author"
    assert comment(a, "question:" <> q.id).role == "author"
    assert comment(actor(user("Calm Peach")), "question:" <> q.id).role == "member"
  end

  test "guest writes and short questions are rejected" do
    assert {:error, _} =
             Question
             |> Ash.Changeset.for_create(:create, %{
               title: "Question",
               topic: "Gleam",
               body: "Some longer details here"
             })
             |> Ash.create(actor: nil)

    a = actor(user())

    assert {:error, _} =
             Question
             |> Ash.Changeset.for_create(:create, %{title: "x", topic: "", body: "short"},
               actor: a
             )
             |> Ash.create(actor: a)
  end

  test "question and comment posting limits are enforced by Ash" do
    a = actor(user())
    p = post()
    for _ <- 1..3, do: question(a)

    assert {:error, _} =
             Question
             |> Ash.Changeset.for_create(
               :create,
               %{title: "Another question", topic: "Gleam", body: "Detailed question here"},
               actor: a
             )
             |> Ash.create(actor: a)

    for _ <- 1..10, do: comment(a, p.id)

    assert {:error, _} =
             Comment
             |> Ash.Changeset.for_create(:create, %{thread_id: p.id, body: "too fast"}, actor: a)
             |> Ash.create(actor: a)
  end

  test "bookmarks are private and post removal cleans associated data" do
    p = post()
    a = actor(user())
    b = actor(user("Calm Peach"))

    Bookmark
    |> Ash.Changeset.for_create(:create, %{post_id: p.id}, actor: a)
    |> Ash.create!(actor: a)

    assert length(Ash.read!(Bookmark, actor: a)) == 1
    assert Ash.read!(Bookmark, actor: b) == []
    comment(a, p.id)
    assert :ok = Ash.destroy(p, actor: admin())
    assert Ash.read!(Bookmark, actor: a) == []
    assert SourceCat.Repo.aggregate(Comment, :count) == 0
  end
end
