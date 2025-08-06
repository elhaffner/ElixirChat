defmodule MyApp.CLI do
  use GenServer
  require Logger

  @moduledoc """
  This module handles the Server CLI. An input loop is started to continuously prompt the user for input.
  """

  #####################
  ###  PUBLIC APIS  ###
  #####################

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: :cli_listener)
  end

  ###################
  ###  CALLBACKS  ###
  ###################

  @doc """
  Starts the GenServer. A separate task starts the input loop.
  """
  def init(state) do
    Process.flag(:trap_exit, true)
    IO.puts("CLI has started. Type 'help' for commands.\n")
    Task.start(fn -> input_loop() end)
    {:ok, state}
  end

  #########################
  ###  PRIVATE METHODS  ###
  #########################

  #Handles the input loop.
  defp input_loop() do
    :timer.sleep(20)
    IO.write("> ")
    input = IO.gets("") |> String.trim()
    handle_command(input)
    input_loop() #Call to input loop again to ask for next input
  end

  #Command parser. Based on the command inputted, calls the right function in the Client.Client GenServer and passes in arguments if relevant.
  defp handle_command(command) do
    case String.split(command) do
      ["create", roomName] ->
        MyApp.RoomSupervisor.start_room(roomName)

      ["delete", roomName] ->
        MyApp.RoomSupervisor.delete_room(roomName)

      ["listRooms"] ->
        room_names = Registry.select(MyApp.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
        IO.puts("[SERVER]: Rooms currently available:")
        Enum.each(room_names, &IO.puts(" - #{&1}"))

      ["invite", room, user] ->
        MyApp.ChatRoom.invite_user(room, user)

      ["help"] ->
        show_help()

      ["exit"] ->
        System.halt(0)

      _ ->
        IO.puts("Unknown command. Type 'help' for usage.")
    end
  end

  #Help Menu
  defp show_help do
    IO.puts("""
    Available Commands (terms in all capitals are variable names):

      create ROOM         - Create a new chat room
      delete ROOM         - Deletes a room
      listRooms           - Lists all rooms currently on the server
      invite ROOM USER    - Invite a user to a room
      help                - Show this help message
      exit                - Exit the CLI
    """)
  end
end
