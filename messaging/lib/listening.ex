defmodule MyApp.Listening do
  use GenServer
  require Logger

  @port 5000

  def start_link(opts) do
    Logger.info("Listening server Starting...")
    GenServer.start_link(__MODULE__, %{listen_socket: nil}, opts)
  end

  @impl true
  def init(state) do
    case :gen_tcp.listen(@port, [:binary, reuseaddr: true, active: false]) do
      {:ok, listen_socket} ->
        send(self(), :accept)

        Logger.info("Accepting connections on port #{@port}...")
        {:ok, %{listen_socket: listen_socket}}

      {:error, reason} ->
      Logger.error("Failed to listen on port #{@port}: #{inspect(reason)}")
      {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, state) do
    case :gen_tcp.accept(state[:listen_socket]) do
      {:ok, client_socket} ->
        Logger.info("Accepted a connection")

        {:ok, pid} = MyApp.ConnectionSupervisor.save_connection(client_socket)
        #Set controlling process to the new pid
        :ok = :gen_tcp.controlling_process(client_socket, pid)

        send(self(), :accept)

        {:noreply, state}

      {:error, reason} ->
        Logger.error("Accept error: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end
end
