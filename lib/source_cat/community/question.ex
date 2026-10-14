defmodule SourceCat.Community.Question do
  use Ash.Resource,
    domain: SourceCat.Community,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  sqlite do
    table "questions"
    repo SourceCat.Repo
  end

  typescript do
    type_name "Question"
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :user_id, :string do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :topic, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
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
      accept [:title, :topic, :body]
      validate string_length(:title, min: 3, max: 180)
      validate string_length(:topic, min: 1, max: 60)
      validate string_length(:body, min: 10, max: 10000)
      change {SourceCat.Changes.CommunityWrite, kind: :question}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end
  end
end
