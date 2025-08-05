defmodule Client do
  use GenServer
  require Logger

  @moduledoc """
  This module can be used to interact with the chat application from the client side. Methods in this GenServer
  are used to handle joining rooms, sending messages, and receiving messages from the application.
  """

  #The host application works on port 5000, ip address is set to localhost for example.
  @ip {127, 0, 0, 1}
  @port 5000

  #####################
  ###  PUBLIC APIS  ###
  #####################

  @doc """
  Wrapper to start a client connection.

  ##Parameters
    - userName: this is the userName the client will used to join rooms.
  """
  def start_link(userName) do
    GenServer.start_link(Client, %{userName: userName, socket: nil, room: :nil}, name: :client)
  end

  @doc """
  Wrapper to send a message to the server.

  ##Parameters
    -message: message to be sent.
  """
  def send_message(payload) do
     GenServer.cast(:client, {:send_message, payload})
  end

  @doc """
  Wrapper for client to join a room.

  ##Parameters
    -room_id: the room to join.
  """
  def join_room(room_id) do
    GenServer.call(:client, {:join_room, room_id})
  end


  def leave_room() do
    GenServer.call(:client, {:leave_room})
  end

  def check_invited_rooms() do
    GenServer.call(:client, {:which_rooms_have_I_been_invited})
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Initiate a client server. Sends a message to connect to the chat room application in a separate server. This is
  to let the init process stop. If :gen_tcp.connect/3 takes a while to respond, the GenServer might restart.

  ##Parameters
    -state: state of the client server
  """
  @impl true
  def init(state) do
    send(self(), :connect)
    {:ok, state}
  end

  @doc """
  Handles the call join a room. Depending on the response of the join room request,
  the user is notified if the join was successful or not.

  ##Parameters
    -{:join_room, room_id}: the room to join
  """
  @impl true
  def handle_call({:join_room, room_id}, _from, state) do

      msg = %{ "command" => "JOIN", "room_id" => room_id, "userName" => state.userName }
      json_msg = Jason.encode!(msg) <> "\n"

      case :gen_tcp.send(state[:socket], json_msg) do
        :ok ->
          new_state = Map.put(state, :room, room_id)
          Logger.info(new_state)
          {:reply, :ok, new_state}
        {:error, reason} ->
          Logger.error("Failed to send join request #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  def handle_call({:leave_room}, _from, state) do
    if state[:room] != nil do
      msg = %{ "command" => "LEAVE", "room_id" => state[:room], "userName" => state.userName }
      json_msg = Jason.encode!(msg) <> "\n"

      case :gen_tcp.send(state[:socket], json_msg) do
        :ok ->
          new_state = Map.put(state, :room, nil)
          Logger.info("You have left the room")
          {:reply, :ok, new_state}
        {:error, reason} ->
          Logger.error("Failed to send leave request #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end

    else
      Logger.error("Please join a room first")
    end
  end

  def handle_call({:which_rooms_have_I_been_invited}, _from, state) do
    msg = %{ "command" => "CHECK_ROOMS", "userName" => state.userName }
    json_msg = Jason.encode!(msg) <> "\n"

    case :gen_tcp.send(state[:socket], json_msg) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        Logger.error("Failed to send check room request #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end


  @doc """
  Handles sending a message from the client side. First checks if a room is already set for the client
  to communicate to. If a room is set, the message is added to a string along with the userName and the room_id
  to be sent to the chat server.

  ##Parameters
    -{:send_message, msg}: the message to be sent.
  """
  @impl true
  def handle_cast({:send_message, payload}, state) do
    case state[:room] do
    nil ->
      Logger.info("Please join a room first")
      {:noreply, state}
    _room ->
      Logger.info("Sending message : #{payload}")
      msg = %{"command" => "MSG", "room_id" => state[:room], "userName" => state[:userName], "message" => payload}
      json_msg = Jason.encode!(msg) <> "\n"

      case :gen_tcp.send(state[:socket], json_msg) do
        :ok ->
          {:noreply, state}

        {:error, reason} ->
          Logger.error("Failed to send message on #{@port}: #{inspect(reason)}")
          {:stop, reason}
      end
    end
  end

  @doc """
  Handles the client iniating a socket with the application. Once connection is established, the socket is added to this client's state.

  ##Parameters
    -state:  state of the GenServer.
  """
  @impl true
  def handle_info(:connect, state) do
    Logger.info("Connecting to #{:inet.ntoa(@ip)}:#{@port}")

    case :gen_tcp.connect(@ip, @port, [:binary, active: true, packet: :line]) do #Set packet: :line -> this means every tcp packet is terminated by a newline.

      {:ok, socket} ->

        log_user_msg = %{"command" => "LOGIN", "userName" => state.userName}
        json_msg = Jason.encode!(log_user_msg) <> "\n"

        :gen_tcp.send(socket, json_msg)

        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
      Logger.error("Failed to connect on port #{@port}: #{inspect(reason)}")
      {:stop, reason}
    end
  end

  #Handles receiving TCP messages. This is where messages arrive when other users in the same room post messages for example.

  ##Parameters
   # -data:  contains the tcp messages sent to the client.
  @impl true
  def handle_info({:tcp, _, data}, state) do
    case String.trim(data) do
      "DELETE_ROOM" ->
        Logger.info("Room #{state[:room]} has been deleted.")
        new_state = %{state | room: nil}
        {:noreply, new_state}
      _ ->
        Logger.info("#{data}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}

  @impl true
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

end
