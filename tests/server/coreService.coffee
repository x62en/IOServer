module.exports = class CoreChat

    constructor: ->
        @users = []
    
    register: (socket, data) ->
        if data.nickname
            @users.push data.nickname