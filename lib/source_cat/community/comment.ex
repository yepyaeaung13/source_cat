defmodule SourceCat.Community.Comment do
  use Ash.Resource,
    domain: SourceCat.Community,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "comments"
    repo SourceCat.Repo
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :thread_id, :string do
      allow_nil? false
      public? true
    end

    attribute :user_id, :string do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :string do
      default "member"
      public? true
    end

    attribute :parent_id, :string do
      default ""
      constraints allow_empty?: true
      allow_nil? false
      public? true
    end

    attribute :root_id, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :deleted, :boolean do
      default false
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at do
      public? true
    end

    update_timestamp :updated_at
  end

  actions do
    read :read do
      primary? true
    end

    create :create do
      primary? true
      accept [:thread_id, :parent_id, :body]
      validate string_length(:body, min: 1, max: 2000)
      change {SourceCat.Changes.CommunityWrite, kind: :comment}
    end

    update :remove do
      require_atomic? false
      accept []
      change set_attribute(:body, "")
      change set_attribute(:deleted, true)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if SourceCat.Checks.VisibleThread
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action(:remove) do
      authorize_if actor_attribute_equals(:admin, true)
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end
