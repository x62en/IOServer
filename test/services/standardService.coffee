module.exports = class StandardService
    constructor: (@app) ->

    _get_session: (sid) ->
        # Retrieve session ID
        return @app.sessions.get sid
        

    # Socket.io events
    hello: (socket, data) ->
        socket.emit 'answer', { status: 'ok', msg: "Hello #{data}!" }
    
    sync_hello: (socket, data, callback) ->
        callback { status: 'ok', msg: "Hello #{data}!" }
    
    errored: (socket, data) ->
        throw 'I can not run'
    
    _forbidden: (socket, data) ->
        console.error 'You should not be here !!'
        socket.emit 'forbidden call', 'OH NO!'