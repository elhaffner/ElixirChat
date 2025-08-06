defmodule MyApp.ChatRoom do
  use GenServer
  require Logger


  @moduledoc """
  Each instance of this module handles a single chat room. Each chat room is identified via a room id on the registry,
  and contains a list of invited user names. Once users join the room, their client socket is connected to the chat room.

  Each chat room also stores past messages in a list. Once a user joins for the first time, all messages are sent to the user.
  When a user tries to send a message to a a chat room, the receive_message function is called and that message gets broadcast
  to all connected clients.
  """


  #####################
  ###  PUBLIC APIS  ###
  #####################

  @doc """
  Wrapper function to start the GenServer.

  ## Parameters
    -room_id: Takes in a room_id - this is the identifier for this chat room's process.
  """
  def start_link(room_id) do
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}} #Add the chat room to the server.
    GenServer.start_link(__MODULE__, %{room_id: room_id, users: %{}, messages: []}, name: via_tuple)
  end

  @doc """
  Wrapper function to handle inviting a user

  ## Parameters
    -room_id: Identifies room to invite user to.
    - userName: string to define name of user to add to invite list.
  """
  def invite_user(room_id, userName) do
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}} #Get name of registry
    GenServer.cast(via_tuple, {:invite_user, userName})
  end

  @doc """
  Wrapper function to handle user joining a room. Checks if a room is registered in the registry
  before proceeding to call :join_room.

  ## Parameters
    -room_id: This is the room the user wants to join
    - userName: This is the user's username
    - client_socket: socket to communicate back to client if room join is successful. Also, this socket will be
    stored in the chatRooms map if join is successful.
  """
  def join_room(room_id, userName, client_socket) do
    #If Registry.lookup returns an empty list, then room hasn't been created yet.
    case Registry.lookup(MyApp.Registry, room_id) do
      [{pid, _value}] ->
        GenServer.call(pid, {:join_room, userName, client_socket})
      [] ->
        {:error, :room_does_not_exist}
    end
  end

  @doc """
  Wrapper function to handle a user leaving a room. The function first checks whether the room already
  exists and then calls :leave_room.
  ## Parameters
    - room_id: This is the room the user wants to leave
    - userName: the user's username
  """
  def leave_room(room_id, userName, client_socket) do
    case Registry.lookup(MyApp.Registry, room_id) do
      [{pid, _value}] ->
        GenServer.call(pid, {:leave_room, userName, client_socket})
      [] ->
        {:error, :room_does_not_exist}
    end
  end

  @doc """
  Wrapper function to receive a message from a user, for a specific room.

  ## Parameters
    - room_id: This is the room the user wants to send a message to.
    - userName: This is the user name of the user sending a message.
    - message: text a user wants to send.
  """
  def receive_message(room_id, userName, message) do
    via_tuple = {:via, Registry, {MyApp.Registry, room_id}}
    GenServer.cast(via_tuple, {:handle_receive_message, userName, message})
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Initiates ChatRoom GenServer.
  ## Parameters
    - state: state of GenServer.
  """
  @impl true
  def init(state) do
    Logger.info("[SERVER]: Room has been created with name: #{state.room_id}")
    {:ok, state}
  end

  @doc """
  Used to invite a user to a chat room. What this does is put the given user name
  in the GenServer's state.user map for future reference.
  ## Parameters
    - {:invite_user, userName}: the username of the user to be invited
    - state: GenServer state
  """
  @impl true
  def handle_cast({:invite_user, userName}, state) do
    new_users = Map.put(state.users, userName, nil)
    new_state = %{state | users: new_users}
    Logger.info("[SERVER]: User #{userName} has been invited to room #{state.room_id}")
    {:noreply, new_state}
  end

  # """
  #Used to handle receiving messages. Add new message to message list if user is allowed in the room. Once
  #the message has been added to the state, it is broadcasted to all connected users, including the user that sent it (that
  #way it shows up in everyone's chat.)
  ## Parameters
  #  - {:invite_user, userName}: the username of the user to be invited
  #  - state: GenServer state
  #"""
  @impl true
  def handle_cast({:handle_receive_message, userName, message}, state) do
    timestamp = String.slice(to_string(DateTime.utc_now()), 0, 19)
    msg = %{user: userName, body: message, timestamp: timestamp}

    colour_timestamp = IO.ANSI.format([:green, "[#{timestamp}]"]) |> IO.iodata_to_binary()
    colour_room_id = IO.ANSI.format([:light_magenta, "[/#{state[:room_id]}]"]) |> IO.iodata_to_binary()
    colour_username = IO.ANSI.format([:light_yellow, "[#{userName}]"])  |> IO.iodata_to_binary()

    new_messages = state.messages ++ [msg]

    #Loop over every socket in the state.user map.
    Enum.each(state.users, fn {_user, socket} ->
      if socket != nil do
        sendData(socket, "#{colour_timestamp}#{colour_room_id}#{colour_username}: #{message}\n") #Send message string with the username included, this allows for identification in the chat.
      end
    end)

    {:noreply, %{state | messages: new_messages}} #Update state with new message
  end

  @doc """
  This function handles a user joining a given chat room instance. It first checks if the user is in the state,
  and then if they already have a socket logged. (If they do, they have already joined and cannot rejoin). The user's client socket
  is then added to the state, and all past messages in the chat room are sent to the user.
  ## Parameters
    - {:invite_user, userName, client_socket}: the username of the user to be invited and the client_socket to communicate with their machine.
    - state: GenServer state
  """
  @impl true
  def handle_call({:join_room, userName, client_socket}, _from, state) do
    if Map.has_key?(state.users, userName) do

      #If the key exists but the value is empty, user is yet to join.
      if state.users[userName] == nil do
        new_users = Map.put(state.users, userName, client_socket)
        new_state = %{state | users: new_users}


        Enum.each(state.messages, fn %{user: from_user, body: msg, timestamp: time_stamp} ->
          colour_timestamp = IO.ANSI.format([:light_black, "[#{time_stamp}]"]) |> IO.iodata_to_binary()
          colour_room_id = IO.ANSI.format([:light_magenta, "[/#{state[:room_id]}]"]) |> IO.iodata_to_binary()
          colour_username = IO.ANSI.format([:light_yellow, "[#{from_user}]"])  |> IO.iodata_to_binary()
          sendData(client_socket, "#{colour_timestamp}#{colour_room_id}#{colour_username}: #{msg}\n")
        end)

        GenServer.cast(self(), {:handle_receive_message, "Server", "User #{userName} has joined the room!"})

        {:reply, :ok, new_state}

      else
        #Error handling if user already joined
        {:reply, {:error, :already_joined}, state}
      end

    else
      #Error handling for users that are not invited.
      {:reply, {:error, :user_not_invited}, state}
    end

  end

  #Callback function for user to leave room.
  ## Parameters
  # - userName: the username of the user trying to leave the room.
  @impl true
  def handle_call({:leave_room, userName, _client_socket}, _from , state) do
    if Map.has_key?(state.users, userName) do

      #If the key exists but the value is empty, user has already left the room or is yet to join.
      #If a socket has been connected to the username, remove it from the map. The user will still remain invited.
      if state.users[userName] != nil do
        new_users = Map.put(state.users, userName, nil)
        new_state = %{state | users: new_users}

        #Send a message to the chatroom notifying other users that the user has left.
        GenServer.cast(self(), {:handle_receive_message, "Server", "User #{userName} has left the room!"})

        {:reply, :ok, new_state}

      else
        #Error handling if user already joined
        {:reply, {:error, :user_has_already_left}, state}
      end

    else
      #Error handling for users that are not invited.
      {:reply, {:error, :user_not_invited}, state}
    end
  end

  #Checks if a user is invited to a chat room. Returns a boolean value.
  @impl true
  def handle_call({:user_invited, userName}, _from, state) do
    if Map.has_key?(state.users, userName) do
      {:reply, true, state}
    else
      {:reply, false, state}
    end
  end

  #When a room is deleted, all users currently in the room should be notified.
  @impl true
  def handle_call({:notify_deletion}, _from, state) do
    Enum.each(state.users, fn {_user, socket} ->
      if socket != nil do
        #Logger.info("Sending delete room")
        sendData(socket, "DELETE_ROOM\n")
      end
    end)
    {:reply, :ok, state}
  end

  #########################
  ###  PRIVATE METHODS  ###
  #########################

  #This is a private method to handle errors when sending messages over tcp.

  ## Parameters
  #  - socket: the socket over which the message will be sent
  #  - msg: the message to be sent.
  #
  defp sendData(socket, msg) do
    case :gen_tcp.send(socket, msg) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to send not-invited response: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
