defmodule SourceCatWeb.Plugs.CurrentActor do
  import Plug.Conn
  alias SourceCat.Accounts.{User, Session}
  def init(opts), do: opts

  def call(conn, _opts) do
    session =
      case get_session(conn, :account_session) do
        id when is_binary(id) -> Ash.get!(Session, id, authorize?: false, not_found_error?: false)
        _ -> nil
      end

    session =
      if session && session.expires_at > System.system_time(:second), do: session, else: nil

    user =
      if session && session.user_id,
        do: Ash.get!(User, session.user_id, authorize?: false, not_found_error?: false),
        else: nil

    actor =
      cond do
        session && (user || session.admin) ->
          %{
            id: user && user.id,
            name: if(user, do: user.name, else: "SourceCat"),
            admin: session.admin
          }

        true ->
          nil
      end

    conn
    |> assign(:current_actor, actor)
    |> assign(:current_user, user)
    |> assign(:account_session, session)
    |> Ash.PlugHelpers.set_actor(actor)
  end

  def sign_in(conn, user_id, admin) do
    conn = revoke(conn)
    id = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    record =
      Session
      |> Ash.Changeset.for_create(:create, %{
        id: id,
        user_id: user_id,
        admin: admin,
        expires_at: System.system_time(:second) + 7200
      })
      |> Ash.create!(authorize?: false)

    conn
    |> configure_session(renew: true)
    |> put_session(:account_session, id)
    |> assign(:account_session, record)
    |> call([])
  end

  def revoke(conn) do
    case conn.assigns[:account_session] do
      nil ->
        conn

      record ->
        Ash.destroy!(record, authorize?: false)
        conn |> delete_session(:account_session) |> assign(:account_session, nil)
    end
  end

  def ip_key(conn) do
    client_ip(conn)
    |> :inet.ntoa()
    |> to_string()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16()
  end

  defp client_ip(conn) do
    header =
      case Application.get_env(:source_cat, :client_ip_proxy) do
        :fly ->
          "fly-client-ip"

        :loopback when conn.remote_ip in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}] ->
          "x-forwarded-for"

        _ ->
          nil
      end

    with true <- is_binary(header),
         [value] <- get_req_header(conn, header),
         false <- String.contains?(value, ","),
         {:ok, ip} <- :inet.parse_address(String.to_charlist(String.trim(value))) do
      ip
    else
      _ -> conn.remote_ip
    end
  end
end
