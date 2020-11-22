module.exports = class UserManager

    constructor: (@app) ->
        @users = {}

    # Check a nickname already exists
    exists: (nickname) ->
        for uid of @users
            if @users[uid].nickname is nickname
                return true
        return false
    
    # Register a new user
    register: (user_id, nickname, imgid) ->
        if user_id not of @users
            @users[user_id] = {
                "nickname": nickname
                "status": "online"
                "uid": user_id
                "imgid": imgid
            }
        
        return @users[user_id]
    
    # Retrieve specific user info
    get_user: (user_id) ->
        if user_id not of @users
            throw "User does not exists"
        return @users[user_id]
    
    # Check if a user is already registered
    is_registered: (user_id) ->
        if user_id of @users
            return true
        return false
    
    # Remove a user
    remove: (user_id) ->
        if user_id not of @users
            throw "User does not exists"
        delete @users[user_id]
    
    # Change user current status
    status: (user_id, current_status) ->
        if user_id not of @users
            throw "User does not exists"
        @users[user_id].status = current_status
    
    # Return users list
    list: ->
        return @users