defmodule MyApp.ChatRoom do
  use GenServer
  require Logger


  #####################
  ###  PUBLIC APIS  ###
  #####################

  def start_link(room_id) do
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}}
    GenServer.start_link(__MODULE__, %{room_id: room_id, users: %{}, messages: []}, name: via_tuple)
  end

  def invite_user(room_id, userName) do
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}}
    GenServer.cast(via_tuple, {:invite_user, userName})
  end

  def join_room(room_id, userName, client_socket) do
    ####################### NEED CHECK HERE TO CHECK IF ROOM EXISTS###############################
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}}
    GenServer.call(via_tuple, {:join_room, userName, client_socket})
  end

  def receive_message(room_id, userName, message) do
    ##Added client_socket as parameter to check if socket is in room_id
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}}
    GenServer.cast(via_tuple, {:handle_receive_message, userName, message})
  end

  ###################
  ###  CALLBACKS  ###
  ###################
  @impl true
  def init(state) do
    Logger.info("Chat room started with id #{state.room_id}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:invite_user, userName}, state) do
    new_users = Map.put(state.users, userName, nil)
    new_state = %{state | users: new_users}
    {:noreply, new_state}
  end


  def handle_cast({:handle_receive_message, userName, message}, state) do
    msg = %{user: userName, body: message}
    new_messages = state.messages ++ [msg]

    Enum.each(state.users, fn {_user, socket} ->
      if socket != nil do
        sendData(socket, "[#{userName}]: #{message}\n")
      end
    end)

    {:noreply, %{state | messages: new_messages}}
  end

  @impl true
  def handle_call({:join_room, userName, client_socket}, _from, state) do
    if Map.has_key?(state.users, userName) do

      if state.users[userName] == nil do
        new_users = Map.put(state.users, userName, client_socket)
        new_state = %{state | users: new_users}


        Enum.each(state.messages, fn %{user: from_user, body: msg} ->
          sendData(client_socket, "[#{from_user}]: #{msg}")
        end)

        {:reply, :ok, new_state}

      else
        {:reply, {:error, :already_joined}, state}
      end

    else
      {:reply, {:error, :user_not_invited}, state}
    end

  end


  #########################
  ###  PRIVATE METHODS  ###
  #########################

  defp sendData(socket, msg) do
    case :gen_tcp.send(socket, msg) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to send not-invited response: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
