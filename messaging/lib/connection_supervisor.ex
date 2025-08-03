defmodule MyApp.ConnectionSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(_arg) do
    Logger.info("Connection Supervisor starting...")
    DynamicSupervisor.start_link(__MODULE__, :ok, name: :connection_supervisor)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def save_connection(client_socket) do
    child_spec = {MyApp.ClientConnection, client_socket}
    DynamicSupervisor.start_child(:connection_supervisor, child_spec)
  end

end
