module.exports = class MessageManager

    constructor: (@app) ->
        @messages = {}
    
    _middleware_check_user: (socket, next) ->
        if not @app.users.is_registered socket.id
            next(new Error('User not registered'))
        else
            next()

    # Register a new message list
    register: (uid) ->
        if uid not of @messages
            @messages[uid] = {
                count: 0
            }
    
    # Add a message
    add: (uid) ->
        if uid not of @messages
            throw "User is not registered"
        @messages[uid].count = ++@messages[uid].count
    
    # Retrieve number of messages sent
    count: (uid) ->
        if uid not of @messages
            throw "User is not registered"
        return @messages[uid].count