defmodule SourceCatWeb.Router do
  use SourceCatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SourceCatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SourceCatWeb.Plugs.CurrentActor
  end

  pipeline :rpc do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :no_store
    plug SourceCatWeb.Plugs.CurrentActor
  end

  scope "/", SourceCatWeb do
    pipe_through :browser
    get "/", PageController, :index
    get "/admin", PageController, :index
    get "/bookmarks", PageController, :index
    get "/community", PageController, :index
    get "/posts/:id", PageController, :post
    get "/community/thread/:id", PageController, :question
  end

  scope "/", SourceCatWeb do
    pipe_through :rpc
    get "/healthz", ContentController, :health
    get "/api/posts", ContentController, :posts
    get "/api/posts/:id", ContentController, :show
    get "/api/questions", CommunityController, :questions
    get "/api/questions/:id", CommunityController, :show
    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
    get "/community/session", AccountController, :state
    post "/community/name", AccountController, :rename
    post "/community/signup", AccountController, :signup
    post "/community/login", AccountController, :login
    post "/community/logout", AccountController, :logout
    post "/community/credentials", AccountController, :credentials
    get "/community/bookmarks", CommunityController, :bookmarks
    post "/community/bookmarks/:id", CommunityController, :bookmark
    post "/community/questions", CommunityController, :create_question
    get "/community/posts/:id/comments/:page", CommunityController, :comments
    post "/community/posts/:id/comments", CommunityController, :add
    get "/community/questions/:id/comments/:page", CommunityController, :question_comments
    post "/community/questions/:id/comments", CommunityController, :answer
    post "/community/comments/:id/delete", CommunityController, :delete
    get "/admin/content", AdminController, :content
    post "/admin/login", AdminController, :login
    post "/admin/logout", AdminController, :logout
    post "/admin/save", AdminController, :save
    post "/admin/delete/:id", AdminController, :delete
  end

  defp no_store(conn, _), do: put_resp_header(conn, "cache-control", "no-store")

  if Application.compile_env(:source_cat, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SourceCatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
