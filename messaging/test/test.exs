# test.exs

defmodule Handler do
  use GenServer
  require Logger

  def start_link(socket) do
    # Start the process without linking for this simple test
    GenServer.start(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    Logger.info("[Handler] Process has started. PID is #{inspect(self())}")
    Logger.info("[Handler] Taking control of socket...")
    :ok = :gen_tcp.controlling_process(socket, self())
    Logger.info("[Handler] Setting socket to active, packet: :line")
    :ok = :inet.setopts(socket, [active: :once, packet: :line])
    Logger.info("[Handler] init complete. Waiting for messages.")
    {:ok, %{socket: socket}}
  end

  # A catch-all that CANNOT fail to match
  @impl true
  def handle_info(message, state) do
    IO.puts("\n\n>>>>>>>>>> [Handler] MESSAGE RECEIVED! <<<<<<<<<<")
    IO.inspect(message, label: "The message is")
    {:noreply, state}
  end
end

defmodule Listener do
  def run do
    port = 5000
    Logger.info("[Listener] Starting to listen on port #{port}")
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, reuseaddr: true, active: false])
    Logger.info("[Listener] Now accepting connections...")
    accept_loop(listen_socket)
  end

  defp accept_loop(listen_socket) do
    Logger.info("[Listener] Waiting in accept_loop...")
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    Logger.info("[Listener] Accepted a connection. Starting a Handler.")
    Handler.start_link(socket)
    accept_loop(listen_socket)
  end
end

# Start the listener
Listener.run()
