module.exports = class AccessMiddleware 
    handle: (@app) ->
        (socket, next) =>
            try
                if not @app.sessions.exists(socket.id)
                    @app.sessions.create(socket.id)
            catch err
                return next(new Error(err))
            next()