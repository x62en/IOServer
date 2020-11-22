module.exports = class RegistrationService
    constructor: (@app) ->

    _get_session: (sid) ->
        # Retrieve session ID
        return @app.sessions.get sid

    register: (socket, data, callback) ->
        sid = @_get_session socket.id
        # Simulate authentication
        @app.sessions.auth sid, true
        # Build answer
        msg = { status: 'ok', msg: 'Registration is OK!', sessid: sid }
        # Use callback for sync events
        callback msg