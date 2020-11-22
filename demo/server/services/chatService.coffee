module.exports = class ChatService
    constructor: (@app) ->

    # Socket.io events
    enter: (socket, user) ->
        socket.broadcast.emit 'hello', user
    
    list: (socket, data, callback) ->
        users_list = @app.users.list()
        callback(users_list)

    status: (socket, current_status) ->
        # Retrieve session ID
        sessid = @app.sessions.get socket.id
        # Retrieve user
        user = @app.users.get_user sessid
        # Update status
        @app.users.status sessid, current_status
        # Announce updated status
        socket.broadcast.emit 'status', {user: user.nickname, status: current_status}
        
    message: (socket, text) ->
        # Retrieve session ID
        sessid = @app.sessions.get socket.id
        # Retrieve user
        user = @app.users.get_user sessid
        # Increase message number
        @app.messages.add sessid
        
        # Forward message to room
        console.log "#{user.nickname} say: #{text}"
        # socket.broadcast.emit 'message', text
        
        # Announce number of message modification
        msg_count = @app.messages.count sessid
        socket.broadcast.emit 'message count', {user: user.nickname, number: msg_count}
        
    logout: (socket, uid, callback) ->
        # Retrieve session ID
        sessid = @app.sessions.get socket.id
        # Retrieve user
        user = @app.users.get_user sessid
        # Delete user from users list
        @app.users.remove sessid
        socket.broadcast.emit 'logout', user.nickname
        callback({status: 'ok'})

    # Private methods
    _notAccessible: (socket) ->
        console.error "You should not be here !!"