# defmodule Messaging do
#   use GenServer
#   require Logger

#   @port 5000

#   # Public API
#   def start_link do
#     GenServer.start_link(__MODULE__, %{listen_socket: nil}, name: __MODULE__)
#   end

#   @impl true
#   def init(state) do
#     case :gen_tcp.listen(@port, [:binary, reuseaddr: true]) do
#       {:ok, listen_socket} ->
#         send(self(), :accept)
#         Logger.info("Accepting connections on port #{@port}...")
#         {:ok, %{state | listen_socket: listen_socket}}

#       {:error, reason} ->
#         Logger.error("Failed to listen on port #{@port}: #{inspect(reason)}")
#         {:stop, reason}
#     end
#   end

#   @impl true
#   def handle_info(:accept, %{listen_socket: listen_socket} = state) do
#     case :gen_tcp.accept(listen_socket) do
#       {:ok, client_socket} ->
#         Logger.info("Client connected")

#         # Spawn a new process to handle this client
#         pid = spawn(fn -> Messaging.ClientHandler.handle(client_socket) end)

#         case :gen_tcp.controlling_process(client_socket, pid) do
#           :ok ->
#             Logger.info("Transferred control to #{inspect(pid)}")
#             send(self(), :accept)
#             {:noreply, state}

#           {:error, reason} ->
#             Logger.error("Failed to transfer control: #{inspect(reason)}")
#             :gen_tcp.close(client_socket)
#             {:noreply, state}
#         end

#         # Keep accepting other clients
#         send(self(), :accept)

#         {:noreply, state}

#       {:error, reason} ->
#         Logger.error("Failed to accept connection: #{inspect(reason)}")
#         {:noreply, state}
#     end
#   end
# end

# # New module to handle individual client connections
# defmodule Messaging.ClientHandler do
#   require Logger

#   def handle(socket) do
#     # Make the socket active
#     :ok = :inet.setopts(socket, active: true)

#     loop(socket)
#   end

#   defp loop(socket) do
#     receive do
#       {:tcp, ^socket, data} ->
#         Logger.info("Received: #{inspect(data)}")
#         :gen_tcp.send(socket, data)
#         loop(socket)

#       {:tcp_closed, ^socket} ->
#         Logger.info("Client disconnected")

#       {:tcp_error, ^socket, reason} ->
#         Logger.error("TCP error: #{inspect(reason)}")
#     end
#   end
# end
