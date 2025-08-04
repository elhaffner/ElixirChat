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

    #Deleted Logging
    #{:ok, {client_ip, client_port}} = :inet.peername(client_socket)
    #Logger.info("Client connected from #{inspect(client_ip)}:#{client_port}")

    :ok = :inet.setopts(client_socket, [active: :true, packet: :line])
    {:ok, %{socket: client_socket, room: nil, user: nil}}
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

    #Trim message to remove any leading and ending whitespace,
    #then separate by ":" to retrieve command, room_id, username and message if possible.
    Logger.info("Received #{data}")
    trimmed_message = String.trim(data)
    Logger.info("Trimmed #{trimmed_message}")


    case String.split(trimmed_message, ":") do
      [command, room_id, userName] ->
        case command do
          "JOIN" ->
            Logger.info("JOIN COMMAND")
            #Attempt to join given room.
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
            #Send a message to the given chat room
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



  #########################
  ###  PRIVATE METHODS  ###
  #########################


  @doc """
  This is a private method to handle errors when sending messages over tcp.

  ## Parameters
    - socket: the socket over which the message will be sent
    - msg: the message to be sent. 
  """
  defp sendData(socket, msg) do
    case :gen_tcp.send(socket, msg) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to send not-invited response: #{inspect(reason)}")
        {:error, reason}
    end
  end

end
