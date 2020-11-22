module.exports = class CoreService
    constructor: (@app) ->

    _validNickname: (nickname) ->
        if nickname is undefined or nickname is ''
            throw 'Nickname can not be empty'
        if nickname.length < 3
            throw 'Nickname is too short'
        if nickname.length > 20
            throw 'Nickname is too long'
    
    _existsNickname: (nickname) ->
        if @app.users.exists nickname
            throw 'User already exists'

    # Socket.io events
    register: (socket, data, callback) ->
        # Validations errors are handled by IOServer
        @_validNickname data.nickname
        @_existsNickname data.nickname
        
        # Retrieve session ID
        sessid = @app.sessions.get socket.id
        # Register user
        console.log "Register #{data.nickname}"
        user = @app.users.register sessid, data.nickname, parseInt(data.imgid, 10)
        # Make user session authentified
        @app.sessions.auth sessid, true
        
        # Return user data
        callback(user)
