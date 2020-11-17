module.exports = class SingleChat

    constructor: ->
        @users = []

    _middleware: (socket, next) ->
        if socket.id not in @users
            next(new Error('forbidden'))
        else
            next()

    message: (socket, text) ->
        console.log "Someone say: #{text}."
        socket.broadcast.emit 'message', text
    
    logout: (socket) ->
        if socket.id in @users
            @users.splice @users.indexOf(socket.id), 1 

    _notAccessible: (socket) ->
        console.error "You should not be here !!"