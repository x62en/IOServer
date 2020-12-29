####################################################
#         IOServer - v1.2.4                        #
#                                                  #
#         Damn simple socket.io server             #
####################################################
#             -    Copyright 2020    -             #
#                                                  #
#   License: Apache v 2.0                          #
#   @Author: Ben Mz                                #
#   @Email: 0x42en (at) users.noreply.github.com   #
#                                                  #
####################################################
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Add required packages
http   = require 'http'
closer = require 'http-terminator'

# Set global vars
VERSION    = '1.2.4'
PORT       = 8080
HOST       = 'localhost'
LOG_LEVEL  = ['EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTIFICATION','INFORMATION','DEBUG']
TRANSPORTS = ['websocket','htmlfile','xhr-polling','jsonp-polling']

module.exports = class IOServer
    # Define the variables used by the server
    constructor: (options = {}) ->
        # Set default options
        {verbose, host, port, cookie, mode, cors, middleware} = options

        @host = if host then String(host) else HOST
        try
            @port = if port then Number(port) else PORT
        catch e
            throw new Error 'Invalid port.'
        
        @cookie = if cookie then Boolean(cookie) else false
        @verbose = if String(verbose).toUpperCase() in LOG_LEVEL then String(verbose).toUpperCase() else 'ERROR'
        
        # Process transport mode options
        @mode = []
        if mode
            if String(mode).toLowerCase() in TRANSPORTS
                @mode.push String(mode).toLowerCase()
            else if mode.constructor is Array
                for i,m of mode
                    if String(m).toLowerCase() in TRANSPORTS
                        @mode.push m
        else
            @mode.push 'websocket'
            @mode.push 'polling'
        
        # Setup CORS since necessary in socket.io v3
        @cors = if cors? and cors then cors else {}
        if not @cors.methods
            @cors.methods = ['GET','POST']
        if not @cors.origin
            @cors.origin = ["https://#{@host}","http://#{@host}"]
            
        # Setup internal lists
        @service_list = {}
        @manager_list = {}
        @method_list  = {}
        @middlewares  = {}
        
        # Register the global app handle
        # that will be passed to all entities
        @appHandle = { send: @sendTo }
        @server = null
    
    _logify: (level, text) ->
        current_level = LOG_LEVEL.indexOf @verbose
        if level <= current_level
            if level <= 4
                console.error text
            else
                console.log text
    
    _unique: (arr) ->
        hash = {}
        result = []

        i = 0
        l = arr.length
        while i < l
            unless hash.hasOwnProperty(arr[i])
                hash[arr[i]] = true
                result.push arr[i]
            ++i

        return result

    addManager: ({name, manager}) ->
        if not name
            throw "[!] Manager name is mandatory"
        if name and name.length < 2
            throw "[!] Manager name MUST be longer than 2 characters"
        if name in ['send']
            throw "[!] Sorry this is a reserved name"
        
        if not (manager or manager.prototype)
            throw "[!] Manager MUST be a function"
        
        try
            # Register manager with handle reference
            @manager_list[name] = new manager(@appHandle)
        catch err
            @_logify 3, "[!] Error while instantiate #{name} -> #{err}"

    # Allow to register easily a class to this server
    # this class will be bind to a specific namespace
    addService: ({name, service, middlewares}) ->
        if not (service and service.prototype)
            throw "[!] Service function is mandatory"
        
        # Allow global register for '/'
        if not name
            name = '/'
        
        # Otherwise service must comply certain rules
        else if name.length < 2
            throw "[!] Service name MUST be longer than 2 characters"
        
        try
            @service_list[name] = new service(@appHandle)
        catch err
            @_logify 3, "[!] Error while instantiate #{name} -> #{err}"

        # list methods of object... it will be the list of io actions
        @method_list[name] = @_dumpMethods service
        # Register middlewares if necessary
        @middlewares[name] = if middlewares then middlewares else []

    # Get service running
    getService: (name) -> @service_list[name]

    # Launch socket IO and get ready to handle events on connection
    # Pass web server used for connections
    start: (webapp) ->
        # If nothing set use standard module
        if not webapp?
            webapp = http.createServer()

        d = new Date()
        day = if d.getDate() < 10 then "0#{d.getDate()}" else d.getDate()
        month = if d.getMonth() < 10 then "0#{d.getMonth()}" else d.getMonth()
        hours = if d.getHours() < 10 then "0#{d.getHours()}" else d.getHours()
        minutes = if d.getMinutes() < 10 then "0#{d.getMinutes()}" else d.getMinutes()
        seconds = if d.getSeconds() < 10 then "0#{d.getSeconds()}" else d.getSeconds()
        @_logify 4, "################### IOServer v#{VERSION} ###################"
        @_logify 5, "################### #{day}/#{month}/#{d.getFullYear()} - #{hours}:#{minutes}:#{seconds} #########################"
        
        # Start web server
        @_logify 5, "[*] Starting server on https://#{@host}:#{@port} ..."
        server = webapp.listen @port, @host

        # Start socket.io listener
        @io = require('socket.io')(server, {
            transports: @mode,
            cookie: @cookie
            cors: @cors
        })

        ns = {}

        # Register all managers
        for manager_name, manager of @manager_list
            @_logify 6, "[*] register #{manager_name} manager"
            @appHandle[manager_name] = manager

        # Register each different services by its namespace
        for service_name, service of @service_list
            ns[service_name] = if service_name is '/' then @io.of '/' else @io.of "/#{service_name}"

            # Register middleware for namespace 
            for middleware in @middlewares[service_name]
                mdwr = new middleware()
                ns[service_name].use mdwr.handle(@appHandle)

            # get ready for connection
            ns[service_name].on "connection", @_handleEvents(service_name)
            @_logify 6, "[*] service #{service_name} registered..."
        
        # Create terminator handler
        @stopper = closer.createHttpTerminator {server}
        
    # Force server stop
    stop: ->
        @_logify 6, "[*] Stopping server"    
        if @stopper
            @stopper.terminate()

    # Allow sending message from external app
    sendTo: ({namespace, event, data, room=false, sid=false}={}) =>
        ns = @io.of(namespace || "/")
        # Send event to specific sid if set
        if sid? and sid
            ns.sockets.get(sid).emit event, data
        else
            # Restrict access to clients in room if set
            sockets = if room? and room then ns.in(room) else ns
            sockets.emit event, data

    # Once a client is connected, get ready to handle his events
    _handleEvents: (service_name) ->
        (socket, next) =>
            @_logify 5, "[*] received connection for service #{service_name}"
            
            # The register all user defined functions
            for index, action of @method_list[service_name]
                # does not listen for private methods
                if action.substring(0,1) is '_'
                    continue
                # do not listen for constructor method
                if action is 'constructor'
                    continue
                
                @_logify 6, "[*] method #{action} of #{service_name} listening..."
                socket.on action, @_handleCallback
                                    service: service_name
                                    method: action
                                    socket: socket

    # On a specific event call the appropriate method of object
    _handleCallback: ({service, method, socket}) ->
        return (data, callback) =>
            @_logify 6, "[*] call method #{method} of service #{service}"
            return new Promise (resolve, reject) =>
                try
                    @service_list[service][method](socket, data, callback)
                    resolve()
                catch err
                    reject(err)
            .catch (err) =>
                if typeof err is 'string'
                    err = new IOServerError(err, -1)

                payload = { 
                    status: 'error',
                    type: err.constructor.name or 'Error',
                    message: err.message or null,
                    code: err.code or -1
                }

                @_logify 5, "Error on #{service}:#{method} execution: #{err}"
                if callback
                    callback payload
                else
                    socket.emit 'error', payload
            
    # Based on Kri-ban solution
    # http://stackoverflow.com/questions/7445726/how-to-list-methods-of-inherited-classes-in-coffeescript-or-javascript
    # Thanks ___ ;)
    _dumpMethods: (klass) ->
        result = []
        k = klass.prototype
        while k
            names = Object.getOwnPropertyNames(k)
            result = result.concat(names)
            k = Object.getPrototypeOf(k)
            break if not Object.getPrototypeOf(k) # avoid listing Object properties

        return @_unique(result).sort()

# IO Server error class
module.exports.IOServerError = class IOServerError extends Error
    constructor: (message, code = -1) ->
        super(message)
        @type = @constructor.name
        @code = code
    
    getMessage: () ->
        return @message
    
    getType: () ->
        return @type
    
    getCode: () ->
        return @code

    toJson: () ->
        return {
            message: @message
            type: @type
            code: @code
        }