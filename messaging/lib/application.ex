defmodule MyApp.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Chat Application starting...")
    children = [
      {Registry, keys: :unique, name: MyApp.Registry},
      {MyApp.ConnectionSupervisor, []},
      {MyApp.Listening, name: :listening},
      {MyApp.RoomSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.TopSupervisor]
    Supervisor.start_link(children, opts)
  end
end
