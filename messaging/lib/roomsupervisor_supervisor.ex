defmodule MyApp.RoomSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(_args) do
    Logger.info("RoomSupervisor Starting...")
    DynamicSupervisor.start_link(__MODULE__, :ok, name: :roomsupervisor)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_room(room_id) do
    child_spec = {MyApp.ChatRoom, room_id}
    DynamicSupervisor.start_child(:roomsupervisor, child_spec)
  end
end
