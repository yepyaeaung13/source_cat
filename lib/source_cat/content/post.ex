defmodule SourceCat.Content.Post do
  use Ash.Resource,
    domain: SourceCat.Content,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  sqlite do
    table "posts"
    repo SourceCat.Repo
  end

  typescript do
    type_name "Post"
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :kind, :string do
      allow_nil? false
      default "article"
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :category, :string do
      allow_nil? false
      public? true
    end

    attribute :excerpt, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :body, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :youtube, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :creator, :string do
      default "SourceCat"
      public? true
    end

    attribute :thumbnail, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :status, :string do
      default "draft"
      allow_nil? false
      public? true
    end

    attribute :date, :string do
      default ""
      constraints allow_empty?: true
      public? true
    end

    attribute :minutes, :string do
      default "5 min read"
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

      accept [
        :id,
        :kind,
        :title,
        :category,
        :excerpt,
        :body,
        :youtube,
        :creator,
        :thumbnail,
        :status,
        :date,
        :minutes
      ]

      change SourceCat.Changes.PostContent
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :kind,
        :title,
        :category,
        :excerpt,
        :body,
        :youtube,
        :creator,
        :thumbnail,
        :status,
        :date,
        :minutes
      ]

      change SourceCat.Changes.PostContent
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change SourceCat.Changes.DeletePost
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:admin, true)
    end

    policy action_type(:read) do
      authorize_if expr(status == "published")
    end

    policy action_type([:create, :update, :destroy]) do
      forbid_if always()
    end
  end
end
