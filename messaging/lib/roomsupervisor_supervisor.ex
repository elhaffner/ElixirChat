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
    child_spec = {MyApp.ChatRoom, room_id}
    DynamicSupervisor.start_child(:roomsupervisor, child_spec)
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
