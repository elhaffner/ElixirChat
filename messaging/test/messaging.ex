# defmodule Messaging do
#   use GenServer
#   require Logger

#   @port 5000

#   # Public API
#   def start_link(ip_address) do
#     GenServer.start_link(Messaging, %{listen_socket: nil}, name: :messaging)
#   end

#   # Callbacks
#   @impl true
#   def init(state) do
#     case :gen_tcp.listen(@port, [:binary, reuseaddr: true]) do
#       {:ok, listen_socket} ->
#         send(self(), :accept)

#         Logger.info("Accepting connections on port #{@port}...")
#         {:ok, %{state | listen_socket: listen_socket}}

#       {:error, reason} ->
#       Logger.error("Failed to listen on port #{@port}: #{inspect(reason)}")
#       {:stop, reason}
#       end
#   end

#   @impl true
#   def handle_info(:accept, state) do
#     {:ok, client_socket} = :gen_tcp.accept(state[:listen_socket])
#     Logger.info("Client has been connected")

#     # Make socket active (to receive {:tcp, ...} messages)
#     :ok = :gen_tcp.controlling_process(client_socket, self())
#     :inet.setopts(client_socket, active: true)

#     # Save the client socket in state
#     {:noreply, Map.put(state, :client_socket, client_socket)}
#   end

#   @impl true
#   def handle_info({:tcp, socket, data}, state) do
#     Logger.info("Received #{data}")
#     Logger.info("Sending it back")

#     :ok = :gen_tcp.send(socket, data)

#     {:noreply, state}
#   end

#   @impl true
#   def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}

#   @impl true
#   def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

# end
