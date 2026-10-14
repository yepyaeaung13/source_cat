defmodule SourceCatWeb.DataHelpers do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  def error(conn, code, message), do: conn |> put_status(code) |> json(%{message: message})

  def ash_error(conn, %Ash.Error.Forbidden{}),
    do: error(conn, 403, "You do not have permission to do that.")

  def ash_error(conn, %Ash.Error.Invalid{} = error) do
    message =
      error.errors
      |> Enum.map(fn e ->
        if Map.get(e, :message), do: to_string(Map.get(e, :message)), else: Exception.message(e)
      end)
      |> Enum.join(" ")

    error(conn, if(String.contains?(message, "wait a minute"), do: 429, else: 422), message)
  end

  def ash_error(conn, _), do: error(conn, 422, "Could not save. Check your input and try again.")
  def actor(conn), do: conn.assigns.current_actor
  def admin?(conn), do: actor(conn) && actor(conn).admin
  def date(nil), do: ""
  def date(value), do: DateTime.to_iso8601(value)

  def entry(p),
    do:
      Map.take(p, [
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
      ])

  def comment(c, actor) do
    %{
      id: c.id,
      name: c.name,
      role: c.role,
      parent: c.parent_id,
      root: c.root_id,
      body: c.body,
      deleted: c.deleted,
      date: date(c.inserted_at),
      can_delete: not c.deleted and not is_nil(actor) and (actor.admin or actor.id == c.user_id)
    }
  end

  def question(q, replies \\ 0),
    do: %{
      id: q.id,
      name: q.name,
      title: q.title,
      topic: q.topic,
      body: q.body,
      date: date(q.inserted_at),
      replies: replies
    }

  def page(params) do
    case Integer.parse(to_string(Map.get(params, "page", "1"))) do
      {n, ""} when n in 1..10000 -> {:ok, n}
      _ -> {:error, :invalid}
    end
  end
end
