defmodule SourceCat.Community do
  use Ash.Domain, extensions: [AshTypescript.Rpc]

  resources do
    resource SourceCat.Community.Question
    resource SourceCat.Community.Comment
    resource SourceCat.Community.Bookmark
  end

  typescript_rpc do
    resource SourceCat.Community.Question do
      rpc_action :list_questions, :read
      rpc_action :get_question, :read, get_by: [:id]
      rpc_action :create_question, :create
    end
  end
end
