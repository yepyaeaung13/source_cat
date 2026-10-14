defmodule SourceCat.ImportGleamTest do
  use SourceCat.DataCase
  alias SourceCat.Accounts.Credentials

  test "legacy import preserves PINs, IDs and replies, is read-only and repeatable" do
    path =
      Path.join(
        System.tmp_dir!(),
        "sourcecat-import-#{System.unique_integer([:positive])}.sqlite"
      )

    on_exit(fn -> File.rm(path) end)
    salt = "legacy-salt"
    hash = Credentials.hash("123456", salt)

    payload =
      Jason.encode!(%{
        id: "legacy-post",
        kind: "article",
        title: "Myanmar programming",
        category: "Crash Course",
        body: "<p>Hello</p><script>bad()</script>",
        status: "published",
        creator: "SourceCat"
      })

    script = """
    import sqlite3,sys
    with sqlite3.connect(sys.argv[1]) as db:
      db.execute('CREATE TABLE blog_entries (payload TEXT, created_at INTEGER)')
      db.execute('INSERT INTO blog_entries VALUES (?,1000)',(sys.argv[2],))
      db.execute('CREATE TABLE community_users (id TEXT,name TEXT,credential_kind TEXT,salt TEXT,password_hash TEXT,created_at INTEGER)')
      db.execute('INSERT INTO community_users VALUES (?,?,?,?,?,1000)',('legacy-user','Calm Apple','pin',sys.argv[3],sys.argv[4]))
      db.execute('CREATE TABLE community_questions (id TEXT,user_id TEXT,name TEXT,title TEXT,topic TEXT,body TEXT,created_at INTEGER)')
      db.execute("INSERT INTO community_questions VALUES ('legacy-question','legacy-user','Calm Apple','How to start?','Crash Course','I want to learn programming.',1000)")
      db.execute('CREATE TABLE community_comments (id TEXT,post_id TEXT,user_id TEXT,name TEXT,role TEXT,parent_id TEXT,root_id TEXT,body TEXT,deleted INTEGER,created_at INTEGER)')
      db.execute("INSERT INTO community_comments VALUES ('root','legacy-post','legacy-user','Calm Apple','member','','root','',1,1000)")
      db.execute("INSERT INTO community_comments VALUES ('reply','legacy-post','legacy-user','Calm Apple','member','root','root','Still visible',0,1001)")
      db.execute('CREATE TABLE community_bookmarks (user_id TEXT,post_id TEXT,created_at INTEGER)')
      db.execute("INSERT INTO community_bookmarks VALUES ('legacy-user','legacy-post',1000)")
    """

    assert {_, 0} = System.cmd("python3", ["-c", script, path, payload, salt, hash])
    before = File.read!(path)

    assert {:ok, %{posts: 1, users: 1, questions: 1, comments: 2, bookmarks: 1}} =
             SourceCat.ImportGleam.run(path)

    assert File.read!(path) == before

    assert {:ok, %{posts: 0, users: 0, questions: 0, comments: 0, bookmarks: 0}} =
             SourceCat.ImportGleam.run(path)

    assert {:ok, user} = Credentials.login("calm apple", "123456", "import-ip")
    assert user.id == "legacy-user"
    post = Ash.get!(SourceCat.Content.Post, "legacy-post", actor: nil)
    refute post.body =~ "<script"
    assert DateTime.to_unix(post.inserted_at) == 1000
    reply = Ash.get!(SourceCat.Community.Comment, "reply", actor: nil)
    assert reply.root_id == "root" and reply.parent_id == "root"
    assert Ash.get!(SourceCat.Community.Comment, "root", actor: nil).deleted

    assert [%{post_id: "legacy-post"}] =
             Ash.read!(SourceCat.Community.Bookmark, actor: %{id: user.id, admin: false})
  end
end
