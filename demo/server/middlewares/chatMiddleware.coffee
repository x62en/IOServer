module.exports = class ChatMiddleware
    # Requested function used by IOServer
    handle: (@app) ->
        (socket, next) =>
            try
                sid = socket.handshake.auth.token
                # Add socket.id in session
                @app.sessions.add sid, socket.id
            catch err
                return next(new Error(err))
            try
                @_checkSessionAuthentified sid
                @_registeredUser sid
            catch err
                return next(new Error(err))
            next()
    
    _checkSessionAuthentified: (sid) ->
        if not @app.sessions.is_auth sid
            throw 'User is not authentified'

    _registeredUser: (sid) ->
        if not @app.users.is_registered sid
            throw 'User is not registered'
