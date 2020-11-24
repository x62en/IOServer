module.exports = class InteractService
    constructor: (@app) ->
    
    restricted: (socket) ->
        socket.join 'test'
    
    