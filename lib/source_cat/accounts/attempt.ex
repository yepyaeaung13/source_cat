defmodule SourceCat.Accounts.Attempt do
  use Ash.Resource,
    domain: SourceCat.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "login_attempts"
    repo SourceCat.Repo
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
    end

    attribute :failures, :integer do
      default 0
      allow_nil? false
    end

    attribute :last_at, :integer do
      default 0
      allow_nil? false
    end

    create_timestamp :inserted_at do
      public? true
    end

    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: [:id, :failures, :last_at], update: [:failures, :last_at]]
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
