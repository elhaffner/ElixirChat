defmodule MyApp.Listening do
  use GenServer
  require Logger

  @moduledoc """
  This model accepts new client connections to the server. Once a client connects and a socket
  is created, ownership of the socket is immediately transferred to an instance of MyApp.ClientConnection
  """

  #This application generates connections over port 5000
  @port 5000


  #####################
  ###  PUBLIC APIS  ###
  #####################

  @doc """
  Wrapper function to start Listening GenServer.
  """
  def start_link(_opts) do
    Logger.info("Listening server Starting...")

    #Start the GenServer with a state containing a map, and a key-value pair to store the listening socket.
    GenServer.start_link(__MODULE__, %{listen_socket: nil})
  end



  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Iniates the GenServer. Once a tcp socket for listening is created, this module calls
  handleinfo(:accept)/1 to initiate the accept loop. Acceptance of client connections is delegated
  to another function - if we were to accept these within init/1, then init/1 would never return a
  status to the Supervisor, causing a timeout where the Supervisor kills and restarts the listening process.

  ## Parameters

    -state: Map that contains a a key to store listen_socket
  """
  @impl true
  def init(state) do
    #active is set to false here - this module does not handle incoming messages.
    case :gen_tcp.listen(@port, [:binary, reuseaddr: true, active: false]) do
      {:ok, listen_socket} ->
        send(self(), :accept)

        Logger.info("Accepting connections on port #{@port}...")
        {:ok, %{listen_socket: listen_socket}}

      #Error handling if socket can't be established.
      {:error, reason} ->
      Logger.error("Failed to listen on port #{@port}: #{inspect(reason)}")
      {:stop, reason}
    end
  end


  @doc """
  Calling this function starts an accept loop -> Whenever a new connection request comes in
  on the listen_socket, a client_socket is created. The client_socket is then saved and supervised
  under MyApp.ConnectionSupervisor. Once the GenServer for the client connection is created, the function
  calls itself again.
  """
  @impl true
  def handle_info(:accept, state) do
    case :gen_tcp.accept(state[:listen_socket]) do
      {:ok, client_socket} ->
        Logger.info("Accepted a connection")

        #Creates a new GenServer under the ConnectionSupervisor for this specific client_socket
        {:ok, pid} = MyApp.ConnectionSupervisor.save_connection(client_socket)

        #Change the controlling process to be the newly created server to allow messages to be handled in the MyApp.ClientConnection module
        :ok = :gen_tcp.controlling_process(client_socket, pid)

        send(self(), :accept)

        {:noreply, state}

      #Error Handling
      {:error, reason} ->
        Logger.error("Accept error: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end
end
