defmodule SourceCat.Accounts.User do
  use Ash.Resource,
    domain: SourceCat.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "users"
    repo SourceCat.Repo
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      default &Ash.UUID.generate/0
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :name_key, :string do
      allow_nil? false
    end

    attribute :salt, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :password_hash, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :auth_version, :integer do
      default 1
      allow_nil? false
    end

    create_timestamp :inserted_at do
      public? true
    end

    update_timestamp :updated_at
  end

  actions do
    defaults [
      :read,
      create: [:name, :name_key, :salt, :password_hash],
      update: [:salt, :password_hash, :auth_version]
    ]
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type(:create) do
      forbid_if always()
    end
  end

  identities do
    identity :unique_name, [:name_key]
  end
end
