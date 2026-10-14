defmodule SourceCat.Repo.Migrations.AddQueryIndexes do
  use Ecto.Migration

  def change do
    create index(:posts, [:status, :inserted_at])
    create index(:questions, [:user_id, :inserted_at])
    create index(:questions, [:inserted_at])
    create index(:comments, [:thread_id, :root_id, :inserted_at])
    create index(:comments, [:user_id, :inserted_at])
    create index(:account_sessions, [:user_id])
    create index(:account_sessions, [:expires_at])
  end
end
