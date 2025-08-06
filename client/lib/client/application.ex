defmodule Client.Application do
  use Application
  require Logger

  @moduledoc """
  This module is the root of the client application which allows a user to connect with the chat server. A DynamicSupervisor
  is used here to start the Client GenServer, as well as CLI application to interface with the Client server.

  Upon starting up this application, the user is prompted to enter a username. This is the identifier used by the Chat server
  to determine if a user has been invited to a room. This is also a required input to start the Client.Client script.
  """

  @impl true
  def start(_type, _args) do

    username = get_username()

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Client.DynSupervisor}
    ]

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, _client_pid} = DynamicSupervisor.start_child(Client.DynSupervisor, {Client.Client, username})
    {:ok, _cli_pid} = DynamicSupervisor.start_child(Client.DynSupervisor, {Client.CLI, []})

    {:ok, pid} #Return pid of Top Supervisor
  end

  defp get_username() do
    IO.puts("Welcome to the Chat Application")
    IO.write("Please enter a username to log in: ")
    IO.gets("") |> String.trim()
  end
end
