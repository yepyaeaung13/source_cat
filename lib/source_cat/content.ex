defmodule SourceCat.Content do
  use Ash.Domain, extensions: [AshTypescript.Rpc]

  resources do
    resource SourceCat.Content.Post
  end

  typescript_rpc do
    resource SourceCat.Content.Post do
      rpc_action :list_posts, :read
      rpc_action :get_post, :read, get_by: [:id]
      rpc_action :create_post, :create
      rpc_action :update_post, :update
      rpc_action :delete_post, :destroy
    end
  end
end
