defmodule SourceCat.Repo do
  use AshSqlite.Repo, otp_app: :source_cat

  def write_transactions?, do: true
end
