defmodule Mix.Tasks.SourceCat.ImportGleam do
  use Mix.Task
  @shortdoc "Import a Glimr SourceCat SQLite database without overwriting existing records"
  @moduledoc "Run mix source_cat.import_gleam --database /path/to/data.db. Requires Python 3. Source DB is read-only. Back up the target first. Sessions are intentionally not imported; sign in again with the same PIN."
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [database: :string])
    path = opts[:database] || Mix.raise("Pass --database /path/to/data.db")
    Mix.Task.run("app.start")

    case SourceCat.ImportGleam.run(path) do
      {:ok, counts} ->
        Enum.each(counts, fn {table, count} -> Mix.shell().info("Imported #{count} #{table}") end)

      {:error, message} ->
        Mix.raise(to_string(message))
    end
  end
end
