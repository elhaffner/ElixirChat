defmodule MyApp.Application do
  use Application
  require Logger

  @moduledoc """
  This is the root of the chat server, and is the script called upon 'ies -S mix'. This
  module owns the Supervision tree all top-level modules within the application.

  A list of children it starts:

  MyApp.Registry - used to access a GenServer with a speific room_id

  MyApp.ConnectionSupervisor - A dynamic supervisor that starts a child for every client connection initiated.

  MyApp.Listening - GenServer to accept incoming connection requests, relays them to the connection supervisor.

  MyApp.RoomSupervisor - dynamic supervisor to supervise chat rooms, can start new chat rooms. Each chat room on the server is
  a child of the room supervisor.
  """

  def start(_type, _args) do
    Logger.info("Chat Application starting...")
    children = [
      {Registry, keys: :unique, name: MyApp.Registry},
      {MyApp.ConnectionSupervisor, []},
      {MyApp.Listening, name: :listening},
      {MyApp.RoomSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.TopSupervisor] #one_for_one strategy to restart any server that crashes.
    Supervisor.start_link(children, opts)
  end
end
