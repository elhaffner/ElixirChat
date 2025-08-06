defmodule MyApp.ClientConnection do
  use GenServer
  require Logger

  @moduledoc """
  This module handles a single connection from a client. One single connection (i.e. one terminal) can handle at most
  one user, in one room, over one socket.
  """

  #####################
  ###  PUBLIC APIS  ###
  #####################

  @doc """
  Wrapper function to start the client connection GenServer.

  ## Parameters

    -client_socket: This is the socket with which the chat server can communicate with a client over TCP.
  """
  def start_link(client_socket) do
    GenServer.start_link(__MODULE__, client_socket)
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Initiates the GenServer with a client_socket. The initial state of the server is to set
  room and user to nil.
  ########################CHANGE HERE ######################################################

  ## Parameters

    -client_socket: This is the socket with which the chat server can communicate with a client over TCP.
  """
  @impl true
  def init(client_socket) do
    Logger.info("Client Connection process has started...")

    :ok = :inet.setopts(client_socket, [active: :true, packet: :line])
    {:ok, %{socket: client_socket, user: nil}}
  end

  @doc """
  This function handles an incoming TCP request to the socket. Since the controlling process for a socket is the GenServer, a message
  over a specific socket will arrive to the right GenServer instance. Once the message arrives, it is processed and split into
  it's components to determine its command and call the appropriate function.

  ##Parameters
    - {:tcp, socket, data}: the format of an incoming tcp message, will contain the socket over which
    it was sent, along with the data that was sent over.
    - state: the state of the GenServer, used to send over information.
  """

  @impl true
  def handle_info({:tcp, socket, data}, state) do

    #Trim message to remove trailing whitespace and decode JSON into a map.
    json_payload = Jason.decode!(String.trim(data))
    Logger.info(json_payload)


    case json_payload do
      %{"command" => "LOGIN", "userName" => userName} ->
        Logger.info("#{userName} has logged in")
        #Update the username of the connection.
        %{state | user: userName}

      #Checks the rooms a user has been invited to.
      %{"command" => "CHECK_ROOMS", "userName" => userName} ->
        invite_list = MyApp.RoomSupervisor.check_which_rooms(userName)
        sendData(socket, "[SERVER]: You have already been invited to the following rooms: \n")
        Enum.each(invite_list, fn room ->
          sendData(socket, "#{room}\n")
        end)

        state

      #Connects user to a chat room
      %{"command" => "JOIN", "room_id" => room_id, "userName" => userName} ->
        #Logger.info("JOIN COMMAND")
        #Attempt to join given room.
        case MyApp.ChatRoom.join_room(room_id, userName, state.socket) do
          :ok ->
            #Logger.info("OK")
            sendData(state.socket, "[SERVER]: You joined #{room_id}\n")

            state

          {:error, :already_joined} ->
            #Logger.info("joined")
            sendData(state.socket, "[SERVER]: You have already joined room: #{room_id}\n")

            state

          {:error, :user_not_invited} ->
           #Logger.info("not invited")
            sendData(state.socket, "[SERVER]: You have not been invited to room: #{room_id}\n")

            state

          {:error, :room_does_not_exist} ->
            #Logger.info("Room has not been set up yet")
            sendData(state.socket, "[SERVER]: The room you are trying to join (#{room_id}) does not exist.\n")

            state

          _ ->
            Logger.info("Catch all")
            state
        end

      #Disconnects a user from a room
      %{"command" => "LEAVE", "room_id" => room_id, "userName" => userName} ->
        #Logger.info("LEAVE COMMAND")

        case MyApp.ChatRoom.leave_room(room_id, userName, state.socket) do
          :ok ->
            #Logger.info("OK")
            sendData(state.socket, "[SERVER]: You have left #{room_id}\n")

            state

          {:error, :user_has_already_left} ->
            #Logger.info("Already left")
            sendData(state.socket, "[SERVER]: You have already left room #{room_id}\n")

            state
          {:error, :user_not_invited} ->
            #Logger.info("not invited")
            sendData(state.socket, "[SERVER]: You have already been kicked out of this room: #{room_id}\n")

            state

          {:error, :room_does_not_exist} ->
            #Logger.info("Room has not been set up yet")
            sendData(state.socket, "[SERVER]: The room you are trying to leave (#{room_id}) does not exist (anymore).\n")

            state
        end

      #Sends a message from a user to a given chat room.
      %{"command" => "MSG", "room_id" => room_id, "userName" => userName, "message" => message} ->
        #Logger.info("User wants to send message")
        MyApp.ChatRoom.receive_message(room_id, userName, message)
        state
    end

    {:noreply, state}
  end



  #Handles a TCP connection closing

  ##Patameters
  #  - {:tcp_closed, socket}: the socket that has been closed
  #  - state: state of the GenServer
  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("TCP connection closed: #{inspect(socket)}")
    {:stop, :normal, state}
  end



  #########################
  ###  PRIVATE METHODS  ###
  #########################


  # This is a private method to handle errors when sending messages over tcp.

  ## Parameters
  #  - socket: the socket over which the message will be sent
  #    - msg: the message to be sent.
  defp sendData(socket, msg) do
    case :gen_tcp.send(socket, msg) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to send not-invited response: #{inspect(reason)}")
        {:error, reason}
    end
  end

end
