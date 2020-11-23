####################################################
#         IOServer - v1.0.1                        #
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

fs     = require 'fs'
url    = require 'url'
path   = require 'path'
http   = require 'http'
https  = require 'https'
closer = require 'http-terminator'

crypto = require 'crypto'

CONFIG     = require '../package.json'
PORT       = 8080
HOST       = 'localhost'
LOG_LEVEL  = ['EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTIFICATION','INFORMATION','DEBUG']
TRANSPORTS = ['websocket','htmlfile','xhr-polling','jsonp-polling']

module.exports = class IOServer
    # Define the variables used by the server
    constructor: ({host, port, cookie, verbose, share, secure, ssl_ca, ssl_cert, ssl_key, mode, cors, middleware}) ->
        @host = if host then String(host) else HOST
        try
            @port = if port then Number(port) else PORT
        catch e
            throw new Error 'Invalid port.'
        
        @share = if share then String(share) else null
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
        
        # Setup correct config for web server
        @secure = if secure then Boolean(secure) else false
        if @secure
            @ssl_ca = if ssl_ca then String(ssl_ca) else null
            @ssl_cert = if ssl_cert then String(ssl_cert) else null
            @ssl_key = if ssl_key then String(ssl_key) else null

        # Setup CORS since necessary in socket.io v3
        @cors = if cors and cors.prototype then cors else {}
        if not @cors.methods
            @cors.methods = ['GET','POST']
        if not @cors.origin
            @cors.origin = if @secure then "https://#{@host}" else "http://#{@host}"
        
        # Setup internal lists
        @service_list = {}
        @manager_list = {}
        @method_list  = {}
        @middlewares  = {}
        
        # Register the global app handle
        # that will be passed to all entities
        @appHandle = {}

    addManager: ({name, manager}) ->
        if not name
            throw "[!] Manager name is mandatory"
        if name and name.length < 2
            throw "[!] Manager name MUST be longer than 2 characters"
        
        if not (manager or manager.prototype)
            throw "[!] Manager MUST be a function"
        
        try
            # Register manager with handle reference
            @manager_list[name] = new manager(@appHandle)
        catch err
            if "#{err}".substring('yield() called with no fiber running') isnt -1
                console.error "[!] Error: you are NOT allowed to use fiberized function in constructor..."
            else
                console.error "[!] Error while instantiate #{name} -> #{err}"

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
            console.error "[!] Error while instantiate #{name} -> #{err}"

        # list methods of object... it will be the list of io actions
        @method_list[name] = @_dumpMethods service
        # Register middlewares if necessary
        @middlewares[name] = if middlewares then middlewares else []

    # Get service running
    getService: (name) -> @service_list[name]

    # Allow your small server to share some stuff
    _http_handler: (req, res) =>
        if not @share
            res.writeHead 200
            res.end 'Nothing shared.'
            return
        
        # If a directory is shared
        uri = url.parse(req.url).pathname
        filename = path.join(@share, uri)

        # Hard defined mime-type based on extension
        contentTypesByExtension = {
            '.html': "text/html; charset=utf-8"
            '.css' : "text/css; charset=utf-8"
            '.js'  : "application/javascript; charset=utf-8"
            '.png' : "image/png"
            '.jpeg': "image/jpeg"
            '.jpg' : "image/jpeg"
        }

        # Set default headers
        headers = {
            "Server": "IOServer"
            "Content-Type": "text/plain; charset=utf-8"
            "X-Content-Type-Options": "nosniff"
        }

        # Check file existence
        if not fs.existsSync filename
            res.writeHead 404, headers
            res.write "404 Not Found\n"
            res.end()
            return
            
        # If file is directory search for index.html
        if fs.statSync(filename).isDirectory()
            filename = "#{filename}/index.html"
        
        # Prevent directory listing
        if not fs.existsSync filename
            res.writeHead 403, headers
            res.write "403 Forbidden\n"
            res.end()
            return
        
        try
            content = fs.readFileSync filename, 'binary'
        catch err
            res.writeHead 500, headers
            res.write "#{err}\n"
            res.end()
            return
            
        contentType = contentTypesByExtension[path.extname(filename)]
        
        if contentType
            headers["Content-Type"] = contentType
        
        res.writeHead 200, headers
        res.write content, 'binary'
        res.end()

    # Launch socket IO and get ready to handle events on connection
    start: ->
        d = new Date()
        day = if d.getDate() < 10 then "0#{d.getDate()}" else d.getDate()
        month = if d.getMonth() < 10 then "0#{d.getMonth()}" else d.getMonth()
        hours = if d.getHours() < 10 then "0#{d.getHours()}" else d.getHours()
        minutes = if d.getMinutes() < 10 then "0#{d.getMinutes()}" else d.getMinutes()
        seconds = if d.getSeconds() < 10 then "0#{d.getSeconds()}" else d.getSeconds()
        @_logify 4, "################### IOServer v#{CONFIG.version} ###################"
        @_logify 5, "################### #{day}/#{month}/#{d.getFullYear()} - #{hours}:#{minutes}:#{seconds} #########################"

        # If websocket and server must be secured
        # with certificates
        if @secure
            app = https.createServer {key: fs.readFileSync(@ssl_key),cert: fs.readFileSync(@ssl_cert),ca: fs.readFileSync(@ssl_ca)}, @_http_handler
            @_logify 5, "[*] Starting server on https://#{@host}:#{@port} ..."
        else
            app = http.createServer @_http_handler
            @_logify 5, "[*] Starting server on http://#{@host}:#{@port} ..."

        # Start web server
        server = app.listen @port, @host
        
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
        # if @io
        #     @io.close()
        if @stopper
            @stopper.terminate()

    # Allow sending message of specific service from external method
    interact: ({service, method, data, room=false, sid=false}={}) ->
        ns = @io.of(service || "/")
        # Send event to specific sid if set
        if sid
            sockets.sockets.get(sid).emit method, data
        else
            # Restrict access to clients in room if set
            sockets = if room then ns.in(room) else ns
            sockets.emit method, data

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
        (data, callback) =>
            @_logify 6, "[*] call method #{method} of service #{service}"
            try
                @service_list[service][method] socket, data, callback
            catch err
                @_logify 5, "Error on #{service}:#{method} execution: #{err}"
                if callback
                    callback { error: err }
                else
                    socket.emit 'error', err
            
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

    _logify: (level, text) ->
        current_level = LOG_LEVEL.indexOf @verbose
        if level <= current_level
            if level <= 4
                console.error text
            else
                console.log text

