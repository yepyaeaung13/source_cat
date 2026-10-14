defmodule SourceCat.Community.Bookmark do
  use Ash.Resource,
    domain: SourceCat.Community,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "bookmarks"
    repo SourceCat.Repo
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      default &Ash.UUID.generate/0
    end

    attribute :user_id, :string do
      allow_nil? false
    end

    attribute :post_id, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at do
      public? true
    end

    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:post_id]
      change {SourceCat.Changes.CommunityWrite, kind: :bookmark}
    end
  end

  policies do
    policy action_type([:read, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end
  end

  identities do
    identity :unique_saved_post, [:user_id, :post_id]
  end
end
