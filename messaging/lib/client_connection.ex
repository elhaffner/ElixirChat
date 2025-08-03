defmodule MyApp.ClientConnection do
  use GenServer
  require Logger

  def start_link(client_socket) do
    GenServer.start_link(__MODULE__, client_socket)
  end

  @impl true
  def init(client_socket) do
    Logger.info("Client Connection process has started...")

    {:ok, {client_ip, client_port}} = :inet.peername(client_socket)
    Logger.info("Client connected from #{inspect(client_ip)}:#{client_port}")

    :ok = :inet.setopts(client_socket, [active: :true, packet: :line])
    {:ok, %{socket: client_socket, room: nil, user: nil}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    Logger.info("Received #{data}")
    trimmed_message = String.trim(data)
    Logger.info("Trimmed #{trimmed_message}")

    case String.split(trimmed_message, ":") do
      [command, room_id, userName] ->
        case command do
          "JOIN" ->
            Logger.info("JOIN COMMAND")
            case MyApp.ChatRoom.join_room(room_id, userName, state.socket) do
              :ok ->
                Logger.info("OK")
                sendData(state.socket, "You joined #{room_id}\n")

              {:error, :already_joined} ->
                Logger.info("joined")
                sendData(state.socket, "You have already joined room: #{room_id}\n")

              {:error, :user_not_invited} ->
                Logger.info("not invited")
                sendData(state.socket, "You have not been invited to room: #{room_id}\n")

              _ ->
                Logger.info("Catch all")
              ##############ADD ERROR CASE FOR ROOM DOESN'T EXIST###########################
              end
          ##########ADD CODE FOR OTHER COMMANDS IF NEEDED##################
        end
      [command, room_id, userName, message] ->
        case command do
          "MSG" ->
            Logger.info("User wants to send message")
            MyApp.ChatRoom.receive_message(room_id, userName, message)
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("TCP connection closed: #{inspect(socket)}")
    {:stop, :normal, state}
  end


  ###Private functions
  defp sendData(socket, msg) do
    case :gen_tcp.send(socket, msg) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to send not-invited response: #{inspect(reason)}")
        {:error, reason}
    end
  end


end
