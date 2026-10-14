defmodule SourceCat.Changes.PostContent do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)

    checks = [
      {:id, is_binary(get.(:id)) and Regex.match?(~r/\A[a-zA-Z0-9_-]{1,120}\z/, get.(:id)),
       "Use a slug with letters, numbers, hyphens or underscores."},
      {:title, is_binary(get.(:title)) and String.length(String.trim(get.(:title))) in 1..240,
       "Title is required (up to 240 characters)."},
      {:category,
       is_binary(get.(:category)) and String.length(String.trim(get.(:category))) in 1..60,
       "Topic is required (up to 60 characters)."},
      {:kind, get.(:kind) in ["article", "video"], "Choose article or video."},
      {:status, get.(:status) in ["draft", "published"], "Choose draft or published."},
      {:youtube,
       get.(:kind) != "video" or Regex.match?(~r/\A[a-zA-Z0-9_-]{11}\z/, get.(:youtube) || ""),
       "Enter an 11-character YouTube video ID."},
      {:thumbnail, get.(:thumbnail) in [nil, ""] or safe_https?(get.(:thumbnail)),
       "Use an HTTPS thumbnail URL."}
    ]

    changeset =
      Enum.reduce(checks, changeset, fn {field, valid?, message}, acc ->
        if valid?, do: acc, else: Ash.Changeset.add_error(acc, field: field, message: message)
      end)

    body = get.(:body) || ""

    changeset =
      if String.length(body) > 200_000,
        do:
          Ash.Changeset.add_error(changeset,
            field: :body,
            message: "Keep content below 200,000 characters."
          ),
        else: changeset

    clean = HtmlSanitizeEx.basic_html(body)
    changeset = Ash.Changeset.force_change_attribute(changeset, :body, clean)

    if get.(:kind) == "article" and String.trim(HtmlSanitizeEx.strip_tags(clean)) == "" do
      Ash.Changeset.add_error(changeset,
        field: :body,
        message: "Write some article content first."
      )
    else
      changeset
    end
  end

  defp safe_https?(value) do
    uri = URI.parse(value)
    uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo)
  end
end
