defmodule SourceCat.Accounts.Session do
  use Ash.Resource,
    domain: SourceCat.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "account_sessions"
    repo SourceCat.Repo
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      sensitive? true
    end

    attribute :user_id, :string

    attribute :admin, :boolean do
      default false
      allow_nil? false
    end

    attribute :expires_at, :integer do
      allow_nil? false
    end

    create_timestamp :inserted_at
  end

  actions do
    defaults [:read, :destroy, create: [:id, :user_id, :admin, :expires_at]]
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
