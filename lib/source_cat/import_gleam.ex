defmodule SourceCat.ImportGleam do
  @moduledoc "Imports legacy data into empty identities, retaining PIN hashes and IDs."
  alias SourceCat.Repo
  alias SourceCat.Accounts.User
  alias SourceCat.Community.{Question, Comment, Bookmark}
  alias SourceCat.Content.Post

  def run(path) do
    script = Application.app_dir(:source_cat, "priv/import/read_gleam.py")

    case System.cmd("python3", [script, Path.expand(path)], stderr_to_stdout: true) do
      {output, 0} ->
        data = Jason.decode!(output)

        Repo.transaction(
          fn ->
            posts =
              insert(
                Post,
                Enum.map(data["blog_entries"], fn row ->
                  payload = Jason.decode!(row["payload"])

                  keys = [
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

                  attrs = Map.new(keys, &{&1, payload[Atom.to_string(&1)] || ""})
                  attrs |> Map.update!(:body, &HtmlSanitizeEx.basic_html/1) |> timestamps(row)
                end)
              )

            users =
              insert(
                User,
                Enum.map(data["community_users"], fn r ->
                  if r["credential_kind"] != "pin",
                    do:
                      raise(
                        "Legacy non-PIN account found; migrate it explicitly before importing"
                      )

                  %{
                    id: r["id"],
                    name: r["name"],
                    name_key: String.downcase(r["name"]),
                    salt: r["salt"],
                    password_hash: r["password_hash"],
                    auth_version: 1
                  }
                  |> timestamps(r)
                end)
              )

            questions =
              insert(
                Question,
                Enum.map(data["community_questions"], fn r ->
                  %{
                    id: r["id"],
                    user_id: r["user_id"],
                    name: r["name"],
                    title: r["title"],
                    topic: r["topic"],
                    body: r["body"]
                  }
                  |> timestamps(r)
                end)
              )

            comments =
              insert(
                Comment,
                Enum.map(data["community_comments"], fn r ->
                  %{
                    id: r["id"],
                    thread_id: r["post_id"],
                    user_id: r["user_id"],
                    name: r["name"],
                    role: r["role"],
                    parent_id: r["parent_id"],
                    root_id: r["root_id"],
                    body: r["body"],
                    deleted: r["deleted"] == 1
                  }
                  |> timestamps(r)
                end)
              )

            bookmarks =
              insert(
                Bookmark,
                Enum.map(data["community_bookmarks"], fn r ->
                  %{id: Ash.UUID.generate(), user_id: r["user_id"], post_id: r["post_id"]}
                  |> timestamps(r)
                end)
              )

            %{
              posts: posts,
              users: users,
              questions: questions,
              comments: comments,
              bookmarks: bookmarks
            }
          end,
          log: false
        )

      {_output, _status} ->
        {:error, "Could not read the original database. Check its path and required tables."}
    end
  end

  defp timestamps(attrs, row) do
    dt = DateTime.from_unix!(row["created_at"] || System.system_time(:second))
    dt = %{dt | microsecond: {0, 6}}
    Map.merge(attrs, %{inserted_at: dt, updated_at: dt})
  end

  defp insert(_, []), do: 0

  defp insert(resource, rows) do
    {count, _} = Repo.insert_all(resource, rows, on_conflict: :nothing, log: false)
    count
  end
end
