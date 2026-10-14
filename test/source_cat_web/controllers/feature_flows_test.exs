defmodule SourceCatWeb.FeatureFlowsTest do
  use SourceCatWeb.ConnCase
  import SourceCat.Fixtures

  setup do
    old = Application.get_env(:source_cat, :admin_password)
    Application.put_env(:source_cat, :admin_password, "test-admin-password")
    on_exit(fn -> Application.put_env(:source_cat, :admin_password, old) end)
    :ok
  end

  defp signup(conn) do
    conn = get(conn, "/community/session")
    suggestion = json_response(conn, 200)["suggestion"]
    conn = conn |> recycle() |> post("/community/signup", %{secret: "123456"})
    assert json_response(conn, 200)["user"]["name"] == suggestion
    {conn, suggestion}
  end

  test "Studio protects all writes, drafts stay hidden, and edit cannot create missing posts", %{
    conn: conn
  } do
    assert json_response(get(conn, "/admin/content"), 401)["message"]
    conn = conn |> recycle() |> post("/admin/login", %{password: "test-admin-password"})
    assert json_response(conn, 200)["message"] == "Signed in"

    fields = %{
      id: "draft-item",
      original_id: "",
      title: "Draft article",
      category: "Crash Course",
      kind: "article",
      body: "<p>Useful content</p>",
      status: "draft"
    }

    conn = conn |> recycle() |> post("/admin/save", fields)
    assert json_response(conn, 200)["post"]["status"] == "draft"
    assert get(build_conn(), "/posts/draft-item").status == 404
    conn = conn |> recycle() |> post("/admin/save", Map.put(fields, :original_id, ""))
    assert conn.status == 409

    conn =
      conn
      |> recycle()
      |> post("/admin/save", Map.merge(fields, %{original_id: "draft-item", status: "published"}))

    assert conn.status == 200
    assert get(build_conn(), "/posts/draft-item").status == 200

    assert json_response(get(build_conn(), "/api/posts"), 200)
           |> Enum.any?(&(&1["id"] == "draft-item"))
  end

  test "signup, logout, PIN login and PIN rotation revoke other sessions", %{conn: conn} do
    {conn, name} = signup(conn)

    other =
      build_conn()
      |> get("/community/session")
      |> recycle()
      |> post("/community/login", %{name: String.downcase(name), secret: "123456"})

    assert other.status == 200

    conn =
      conn
      |> recycle()
      |> post("/community/credentials", %{current_secret: "123456", secret: "654321"})

    assert conn.status == 200
    other = other |> recycle() |> get("/community/session")
    assert json_response(other, 200)["user"] == nil
    conn = conn |> recycle() |> post("/community/logout", %{})
    assert json_response(conn, 200)["user"] == nil
    conn = conn |> recycle() |> post("/community/login", %{name: name, secret: "123456"})
    assert conn.status == 401
    conn = conn |> recycle() |> post("/community/login", %{name: name, secret: "654321"})
    assert conn.status == 200
  end

  test "public questions, comments, tombstones, private and idempotent bookmarks", %{conn: conn} do
    p = post()
    assert post(build_conn(), "/community/questions", %{title: "Question"}).status == 401
    {conn, _} = signup(conn)
    conn = conn |> recycle() |> post("/community/bookmarks/" <> p.id, %{saved: "yes"})
    assert json_response(conn, 200) == [p.id]
    conn = conn |> recycle() |> post("/community/bookmarks/" <> p.id, %{saved: "yes"})
    assert json_response(conn, 200) == [p.id]
    assert get(build_conn(), "/community/bookmarks").status == 401

    conn =
      conn
      |> recycle()
      |> post("/community/questions", %{
        title: "Learning Elixir",
        topic: "Crash Course",
        body: "How should I start learning Elixir?"
      })

    q = json_response(conn, 201)["question"]["id"]

    conn =
      conn
      |> recycle()
      |> post("/community/questions/#{q}/comments", %{
        body: "<script>plain text</script>",
        role: "fake"
      })

    comment = json_response(conn, 201)["comment"]
    assert comment["role"] == "author"

    assert json_response(get(build_conn(), "/community/questions/#{q}/comments/1"), 200)["total"] ==
             1

    conn = conn |> recycle() |> post("/community/comments/#{comment["id"]}/delete", %{})
    assert conn.status == 200

    assert json_response(get(build_conn(), "/community/questions/#{q}/comments/1"), 200)[
             "comments"
           ]
           |> hd()
           |> Map.get("deleted")

    assert get(build_conn(), "/community/questions/#{q}/comments/0").status == 422
  end

  test "RPC policies prevent visitor post writes and draft queries", %{conn: conn} do
    p = post()
    post(%{id: "private-draft", status: "draft"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post("/rpc/run", %{action: "list_posts", fields: ["id", "title"]})

    result = json_response(conn, 200)
    assert result["success"]
    assert Enum.map(result["data"], & &1["id"]) == [p.id]

    conn =
      conn
      |> recycle()
      |> post("/rpc/run", %{
        action: "create_post",
        fields: ["id"],
        input: %{id: "forged", title: "Forged", category: "Gleam", body: "<p>Forged</p>"}
      })

    refute json_response(conn, 200)["success"]

    assert Ash.get!(SourceCat.Content.Post, "forged", authorize?: false, not_found_error?: false) ==
             nil
  end

  test "CSRF protection rejects a real browser-style write without a token", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/admin/login", %{password: "test-admin-password"})
    end
  end

  test "conversation pagination keeps replies with their root and hides draft threads", %{
    conn: conn
  } do
    p = post()
    first = actor(user())
    second = actor(user("Calm Peach"))
    roots = for _ <- 1..10, do: comment(first, p.id)
    eleventh = comment(second, p.id)
    reply = comment(second, p.id, %{parent_id: eleventh.id})
    page1 = conn |> get("/community/posts/#{p.id}/comments/1") |> json_response(200)
    page2 = build_conn() |> get("/community/posts/#{p.id}/comments/2") |> json_response(200)
    assert page1["roots"] == 11 and page1["total"] == 12 and page1["pages"] == 2
    assert length(Enum.filter(page1["comments"], &(&1["parent"] == ""))) == 10
    combined = page1["comments"] ++ page2["comments"]
    assert length(combined) == 12
    assert Enum.any?(combined, &(&1["id"] == reply.id))

    containing =
      Enum.find([page1, page2], &Enum.any?(&1["comments"], fn c -> c["id"] == reply.id end))

    assert Enum.any?(containing["comments"], &(&1["id"] == eleventh.id))

    assert MapSet.new(Enum.map(combined, & &1["id"])) ==
             MapSet.new(Enum.map(roots ++ [eleventh, reply], & &1.id))

    p |> Ash.Changeset.for_update(:update, %{status: "draft"}) |> Ash.update!(actor: admin())
    assert get(build_conn(), "/community/posts/#{p.id}/comments/1").status == 404
    assert Ash.read!(SourceCat.Community.Comment, actor: nil) == []
  end

  test "expired sessions and replayed logout cookies cannot authenticate", %{conn: conn} do
    {conn, _} = signup(conn)
    replay = recycle(conn)
    conn = conn |> recycle() |> post("/community/logout", %{})
    assert conn.status == 200
    assert replay |> get("/community/session") |> json_response(200) |> Map.get("user") == nil
    {conn, _} = signup(recycle(conn))
    SourceCat.Repo.update_all(SourceCat.Accounts.Session, set: [expires_at: 1])

    assert conn |> recycle() |> get("/community/session") |> json_response(200) |> Map.get("user") ==
             nil

    assert :ok = SourceCat.Maintenance.cleanup()
    assert SourceCat.Repo.aggregate(SourceCat.Accounts.Session, :count) == 0
  end

  test "only configured proxies supply client addresses for rate limits", %{conn: conn} do
    alias SourceCatWeb.Plugs.CurrentActor
    old = Application.get_env(:source_cat, :client_ip_proxy)
    on_exit(fn -> Application.put_env(:source_cat, :client_ip_proxy, old) end)
    Application.put_env(:source_cat, :client_ip_proxy, :loopback)
    conn = %{conn | remote_ip: {127, 0, 0, 1}}
    forwarded = put_req_header(conn, "x-forwarded-for", "203.0.113.1")
    refute CurrentActor.ip_key(conn) == CurrentActor.ip_key(forwarded)
    public = %{conn | remote_ip: {198, 51, 100, 1}}

    assert CurrentActor.ip_key(public) ==
             CurrentActor.ip_key(put_req_header(public, "x-forwarded-for", "203.0.113.1"))

    assert CurrentActor.ip_key(conn) ==
             CurrentActor.ip_key(
               put_req_header(conn, "x-forwarded-for", "203.0.113.1, 203.0.113.2")
             )

    Application.put_env(:source_cat, :client_ip_proxy, :fly)

    refute CurrentActor.ip_key(conn) ==
             CurrentActor.ip_key(put_req_header(conn, "fly-client-ip", "203.0.113.3"))
  end
end
