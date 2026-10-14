defmodule SourceCat.Maintenance do
  use GenServer
  import Ecto.Query
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(_) do
    Process.send_after(self(), :cleanup, 600_000)
    {:ok, nil}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup()
    Process.send_after(self(), :cleanup, 600_000)
    {:noreply, state}
  end

  def cleanup do
    now = System.system_time(:second)
    SourceCat.Repo.delete_all(from s in SourceCat.Accounts.Session, where: s.expires_at < ^now)

    SourceCat.Repo.delete_all(
      from a in SourceCat.Accounts.Attempt, where: a.last_at < ^(now - 900)
    )

    :ok
  end
end
