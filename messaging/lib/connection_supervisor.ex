defmodule MyApp.ConnectionSupervisor do
  use DynamicSupervisor
  require Logger

  @moduledoc """
  Dynamic Supervisor to handle multiple connections. The reason each connection is given its own GenServer, is
  to help with fault tolerance - i.e. if we handle connections from the chat rooms themselves, a broken connection could result in the
  chat room process stopping. This way, the processes managing the chat room and connections are separated.
  """

  #####################
  ###  PUBLIC APIS  ###
  #####################

  @doc """
  Wrapper function to start the Connection Supervisor.
  """
  def start_link(_arg) do
    Logger.info("Connection Supervisor starting...")
    DynamicSupervisor.start_link(__MODULE__, :ok, name: :connection_supervisor)
  end

  @doc """
  Creates a new connection and passes in a socket for the client.
  """
  def save_connection(client_socket) do
    child_spec = {MyApp.ClientConnection, client_socket}
    DynamicSupervisor.start_child(:connection_supervisor, child_spec)
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Starts connection supervisor with one_for_one strategy
  """
  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end
