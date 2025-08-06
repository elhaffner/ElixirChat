# ElixirChat
Terminal-based chat application built with Elixir.

## Description
This repository contains two Elixir Applications at the top level. </br>
  **/messaging** - Server-side Application </br>
  **/client** - Client-side Application </br>

This chat application works via a central "messaging" server that manages all client connections and chat rooms. An administrator that controls this 
central server can create and delete rooms, as well control which users are allowed to have access. Clients can connect to the chat server via the client-side
application, and log in via a username. The username a client gives upon starting the application will act as their identifier and determine which rooms
they are allowed to join. 

The chat application accepts connections on port 5000, and connection requests have been set to go over '127.0.0.1' for testing purposes. If the IP address of the server is on a different machine (as would be the case in a real-world use) the ip address set in *client.ex* would have to be set to the server IP.

Both the **messaging** and **client** servers can be controlled via a CLI script that automatically starts when the application is run (see Usage Guide section) - the CLI script was added in an attempt to simplify the commands needed to interact with the application. Since this is a terminal-based application, a design decision was made to have each instance of the client-side application only be able to interface with one chat room at once. This was done to prevent messages from different chat rooms arriving on the same terminal. The CLI input displays a ">" character as a visual prompt for new messages, however it is to be noted that incoming messages displayed on the terminal screen sometimes interfere with this. Aside from this aesthetic issue, a user/administrator is still able to type in commands and have them properly processed even when a ">" is not shown on screen. </br>
As such, if a user wants to connect to multiple chat rooms at once, they can open up a new terminal window to start another instance of the client-side server which will allow them to connect to a different chat room. They can (and ideally should), use the same username for this as the server-side application differentiates client instances based on the tcp socket created when logging into the chat server. Users are also able to switch between chat rooms on the same terminal if they wish to do so. 

## Usage Guide
### Server-side
In order for a client to log into the chat server, the chat server first needs to be started on the host machine. The chat server can be started by changing into the ./messaging directory and running the following commands. **mix run --no-halt** is used here to prevent iex from starting, which allows the CLI process to take over. Alternatively, the application can also be started with 'iex -S mix', which will start the iex terminal and allow for more fine-grained control of the server.
```
mix compile
mix run --no-halt
```
Once started, the administrator will be able to manage the chat room using the following commands (variable names are capitalised): </br> </br>
      **create ROOM**         - Create a new chat room </br>
      **delete ROOM**         - Deletes a room </br>
      **listRooms**           - Lists all rooms currently on the server </br>
      **invite ROOM USER**    - Invite a user to a room </br>
      **help**                - Show help message </br>
      **exit**                - Shut down the server </br>
If the chat server shuts down, the client-side sockets will become defunct and client-side servers will have to be restarted once the server is up and running again.

### Client-side
Once the server side script is running, a user can start the client-side server on their machine using the same set of commands:
```
mix compile
mix run --no-halt
```
Once started the application will prompt the user to type in a username, a connection will be established to the chat server, and the user will be able to interact with it using the following commands (varaible names are capitalised): </br> </br>
      **checkRooms**          - lists the rooms a user can join </br>
      **join ROOM**           - join a room </br>
      **leave**               - leaves the current room if you have already joined one </br>
      **send MESSAGE**        - sends a message to the current room </br>
      **help**                - Show this help message </br>
      **exit**                - Shuts down the server </br>
The *MESSAGE* variable can consist of multiple words, and doesn't need to be enclosed in quotation marks - the application will simply consider everything after the 'send' keyword as the message to be sent. It is also worth noting that upon starting, the client application will automatically show the user any rooms they have already been invited to. The same is done whenever a user leaves a room - a 'checkRooms' request will be made, so that the user can decide what room they want to join. The application also handles a series of errors, such as a user trying to join a room that doesn't exist, a user trying to join a room that they haven't been invited to, or a user trying to send a message without having joined a room among others. Where possible these edge cases have been identified to inform the user of what their current connection is capable of doing. 

### Messaging
Each message in the chat room appears as the following </br>
[timestamp][room name][user]: message </br>
Once a client joins a chat room, all previously sent messages are sent to the client - that way they can see past conversations. The timestamps of past messages are highlighted in dark-grey, while newly sent messages after a user joins will have green messages. </br>
Whenever a user sends a message, the message is appended to a list in the chat room state, and also broadcasted to all client sockets currently associated with the room. When users leave or join a room, a notification is sent from the server to all currently connected users in the room. </br> 
The server-side administrator also retains a log of incoming connections and json objects sent over client sockets. 

## Architecture
This section covers the architecure of the client and server-side applications. Both applications were built using GenServers and Supervisors to track the state of the application. 
### Client.Application
The client application is relatively simple and uses a Dynamicsupervisor to manage two GenServers - one called Client.Client which allows access to the chat server, and one for Client.CLI which handles the CLI interface. The client.ex file handles the communication with the chat server via the establishment of a tcp socket. Once a socket is established, individual commands send JSON objects to the server which are then parsed to perform a specific function. For example, in order to join a room, the client will encode the following as JSON.
```
msg = %{ "command" => "JOIN", "room_id" => room_id, "userName" => state.userName }
```
The server can then decode the JSON object and parse the command to determine what action to take on the given parameters (room_id and userName). The client side application is also able to receive messages from the server to print to the terminal (for example, when a message is sent to a chat room the user is connected to, the server will broadcast this message to all connected clients). 

### MyApp.Application
This is the server side application, which uses a Supervisor to manage the following processes: </br>
  **MyApp.Registry** - used to access a GenServer with a speific room_id </br>
  **MyApp.Listening** - GenServer to accept incoming connection requests, relays them to the connection supervisor. </br>
  **MyApp.ConnectionSupervisor** - A dynamic supervisor that starts a child for every client connection initiated. </br>
  **MyApp.RoomSupervisor** - dynamic supervisor to supervise chat rooms, can start new chat rooms. Each chat room on the server is
  a child of the room supervisor. </br>

#### Dynamic Supervisors
A few key decisions were made here - for one, each instance of a client connection (i.e. each client socket established) is managed via a separate process. This allows      the application to separate client socket processes from the processes managing chat rooms. Again, each chat room is also managed via a separate process - the server benefits from separating the two, as one single client should be allowed to switch between rooms. Additionally, this makes the routing of messages between the client and the server simpler; each command from the client can be routed to a specific GenServer instance, which in turn can use MyApp.Registry to identify the right chat room instance to communicate to. </br>
It is to be noted that individual chat room instances (MyApp.ChatRoom) map usernames to client sockets in their state. Having a non-nil value to a username key in a chat room server allows the chat room instance to identify which users are connected to the application. These client sockets are also used directly by the chat room GenServer to send messages over connected user's respective sockets. 

#### MyApp.Listening
The server uses a specified GenServer to handle incoming connection requests. Once a connection request is processed and a tcp socket established, MyApp.Listening then starts a new child (MyApp.ClientConnection) under the ConnectionSupervisor to manage that connection, after which the controlling process of the socket is changed to the new instance of the MyApp.ClientConnection instance. This then allows tcp messages routed to that socket to be handled by the new MyApp.ClientConnection instance. </br>
This way, the application only produces as many client connection instances as it needs (and prevents multiple instances from listening to the same port at once). Furthermore, this also prevents the application from breaking down when a single client connection is interrupted. 















