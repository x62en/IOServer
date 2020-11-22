module.exports = class PrivateService
    constructor: (@app) ->

    # Socket.io events
    message: (socket, msg) ->
        socket.emit 'private answer', "PRIVATE: #{msg}"