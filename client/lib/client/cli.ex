defmodule Client.CLI do
  use GenServer
  require Logger

  @moduledoc """
  This module handles the Client CLI. An input loop is started to continuously prompt the user for input.
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
  Starts the GenServer. In order to allow the user to see what rooms they've been invited to, a call to Client.check_invited_rooms/0 is made.
  A separate task starts the input loop.
  """
  @impl true
  def init(state) do
    IO.puts("CLI has started. Type 'help' for commands.\n")
    Client.Client.check_invited_rooms()
    Task.start(fn -> input_loop() end)
    {:ok, state}
  end

  #########################
  ###  PRIVATE METHODS  ###
  #########################

  #Handles the input loop.
  defp input_loop() do
    :timer.sleep(20) #Allows terminal to print response messages before asking for input again.
    IO.write("> ")
    input = IO.gets("") |> String.trim()
    handle_command(input)
    input_loop() #Call to input loop again to ask for next input
  end

  #Command parser. Based on the command inputted, calls the right function in the Client.Client GenServer and passes in arguments if relevant.
  defp handle_command(command) do
    cond do
      command == "checkRooms" ->
        Client.Client.check_invited_rooms()

      String.starts_with?(command, "join ") ->
        ["join", room_name] = String.split(command, " ", parts: 2)
        Client.Client.join_room(room_name)

      command == "leave" ->
        Client.Client.leave_room()
        Client.Client.check_invited_rooms()

      String.starts_with?(command, "send ") ->
        message = String.trim_leading(command, "send ")
        Client.Client.send_message(message)

      command == "help" ->
        show_help()

      command == "exit" ->
        System.halt(0)

      true ->
        IO.puts("Unknown command. Type 'help' for usage manual.")
    end
  end


  #Help Menu
  defp show_help do
    IO.puts("""
    Available Commands (terms in all capitals are variable names):
      checkRooms          - lists the rooms a user can join
      join ROOM           - join a room
      leave               - leaves the current room if you have already joined one
      send MESSAGE        - sends a message to the current room
      help                - Show this help message
      exit                - Exit the CLI
    """)
  end
end
