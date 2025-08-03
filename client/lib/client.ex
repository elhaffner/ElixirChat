defmodule Client do
  use GenServer
  require Logger

  @ip {127, 0, 0, 1}
  @port 5000

  def start_link(userName) do
    GenServer.start_link(Client, %{userName: userName, socket: nil, room: :nil}, name: :client)
  end

  def send_message(message) do
     GenServer.cast(:client, {:send_message, message})
  end

  def join_room(room_id) do
    GenServer.call(:client, {:join_room, room_id})
  end

  @impl true
  def init(state) do
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_call({:join_room, room_id}, _from, state) do
      msg = "JOIN:#{room_id}:#{state.userName}\n"

      case :gen_tcp.send(state[:socket], msg) do
        :ok ->
          new_state = Map.put(state, :room, room_id)
          Logger.info(new_state)
          {:reply, :ok, new_state}
        {:error, reason} ->
          Logger.error("Failed to send join request #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  @impl true
  def handle_cast({:send_message, msg}, state) do
    case state[:room] do
    nil ->
      Logger.info("Please join a room first")
      {:noreply, state}
    _room ->
      Logger.info("Sending message : #{msg}")
      message = "MSG:#{state[:room]}:#{state[:userName]}:#{msg}\n"

      case :gen_tcp.send(state[:socket], message) do
        :ok ->
          {:noreply, state}

        {:error, reason} ->
          Logger.error("Failed to send message on #{@port}: #{inspect(reason)}")
          {:stop, reason}
      end
    end
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.info("Connecting to #{:inet.ntoa(@ip)}:#{@port}")

    case :gen_tcp.connect(@ip, @port, [:binary, active: true, packet: :line]) do
      {:ok, socket} ->
        {:noreply, %{state | socket: socket}}
      {:error, reason} ->
      Logger.error("Failed to connect on port #{@port}: #{inspect(reason)}")
      {:stop, reason}
    end
  end

  @impl true
  def handle_info({:tcp, _, data}, state) do
    Logger.info("#{data}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}

  @impl true
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

end
