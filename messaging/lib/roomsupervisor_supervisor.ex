defmodule MyApp.RoomSupervisor do
  use DynamicSupervisor
  require Logger

  @moduledoc """
  Dynamic Supervisor to handle multiple chat rooms.
  """

  #####################
  ###  PUBLIC APIS  ###
  #####################


  @doc """
  Wrapper function to start the Room supervisor.
  """
  def start_link(_args) do
    Logger.info("RoomSupervisor Starting...")
    DynamicSupervisor.start_link(__MODULE__, :ok, name: :roomsupervisor)
  end

  @doc """
    Function to start a new chat room (starts new child server to handle this chat room)

  ##Parameters
    - room_id: The room id of the chat room to be started.
  """

  def start_room(room_id) do
    case Registry.lookup(MyApp.Registry, room_id) do
      [{_pid, _value}] ->
        Logger.error("Tried to create a room that already exists.")
      [] ->
        child_spec = {MyApp.ChatRoom, room_id}
        DynamicSupervisor.start_child(:roomsupervisor, child_spec)
    end
  end

  @doc """
  Deletes a room by removing its GenServer from the supervision tree

  ##Parameters
  - room_id: Name of the room to be deleted.
  """
  def delete_room(room_id) do
    #If room is in registry, proceed to delete, otherwise raise an error.
    case Registry.lookup(MyApp.Registry, room_id) do
      [{pid, _value}] ->
      #Starts a call to notify clients of a room deletion 
      case GenServer.call(pid, {:notify_deletion}) do

        :ok ->
          case DynamicSupervisor.terminate_child(:roomsupervisor, pid) do

          :ok ->
            Logger.info("[SERVER]: Room #{room_id} deleted successfully")
            :ok

          {:error, reason} ->
            Logger.error("[SERVER]:Failed to stop room: #{inspect(reason)}")
          end

        {:error, reason} ->
          Logger.error("[SERVER]: Failed to notify clients: #{inspect(reason)}")
      end

      [] ->
        Logger.error("[SERVER]: The room you are trying to remove does not exist. ")
    end
  end

  @doc """
  Returns a list of strings containing the names of rooms a user has been invited to.

  ##Parameters
    - userName: the identifier of the user
  """
  def check_which_rooms(userName) do
    DynamicSupervisor.which_children(:roomsupervisor)
    |> Enum.map( fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(fn pid ->
      GenServer.call(pid, {:user_invited, userName})
    end)
    |> Enum.map(fn pid ->
      " - #{:sys.get_state(pid).room_id}"
    end)
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Starts Room supervisor.
  """
  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
