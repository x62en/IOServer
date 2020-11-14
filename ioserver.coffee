####################################################
#         IOServer - v0.3.3                        #
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
Server = require 'socket.io'
http   = require 'http'
https  = require 'https'
Fiber  = require 'fibers'

CONFIG     = require './package.json'
PORT       = 8080
HOST       = 'localhost'
LOG_LEVEL  = ['EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTIFICATION','INFORMATION','DEBUG']
TRANSPORTS = ['websocket','htmlfile','xhr-polling','jsonp-polling']

module.exports = class IOServer
    # Define the variables used by the server
    constructor: ({host, port, login, cookie, verbose, share, secure, ssl_ca, ssl_cert, ssl_key, mode}) ->
        @host = if host then String(host) else HOST
        try
            @port = if port then Number(port) else PORT
        catch e
            throw new Error 'Invalid port.'
        
        @share = if share then String(share) else null
        @login = if login then String(login) else null
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
        
        @secure = if secure then Boolean(secure) else false
        if @secure
            @ssl_ca = if ssl_ca then String(ssl_ca) else null
            @ssl_cert = if ssl_cert then String(ssl_cert) else null
            @ssl_key = if ssl_key then String(ssl_key) else null

        @service_list = {}
        @method_list = {}

    # Allow to register easily a class to this server
    # this class will be bind to a specific namespace
    addService: ({name, service}) ->
        if name and (name.length > 2) and service and service.prototype
            try
                @service_list[name] = new service()
            catch e
                if "#{e}".substring('yield() called with no fiber running') isnt -1
                    console.error "[!] Error: you are NOT allowed to use fiberized function in constructor..."
                else
                    console.error "[!] Error while instantiate #{name} -> #{e}"

            # list methods of object... it will be the list of io actions
            @method_list[name] = @_dumpMethods service
        else
            @_logify 3 ,"#[!] Service name MUST be longer than 2 characters"

    # Get Instance running
    getInstance: (name) -> @service_list[name]

    # Allow your small server to share some stuff
    _handler: (req, res) =>
        if @share
            files = fs.readdirSync @share
            res.writeHead 200
            
            unless files.length > 0
                res.end 'Shared path empty.'
            
            for file in files
                readStream = fs.createReadStream("#{@share}/#{file}")
                readStream.on 'open', () ->
                    readStream.pipe(res)
                readStream.on 'error', (err) ->
                    res.writeHead 500
                    res.end err
                break
            
        else
            res.writeHead 200
            res.end 'Nothing shared.'
            
    # Launch socket IO and get ready to handle events on connection
    start: () ->
        d = new Date()
        day = if d.getDate() < 10 then "0#{d.getDate()}" else d.getDate()
        month = if d.getMonth() < 10 then "0#{d.getMonth()}" else d.getMonth()
        hours = if d.getHours() < 10 then "0#{d.getHours()}" else d.getHours()
        minutes = if d.getMinutes() < 10 then "0#{d.getMinutes()}" else d.getMinutes()
        seconds = if d.getSeconds() < 10 then "0#{d.getSeconds()}" else d.getSeconds()
        @_logify 4, "################### IOServer v#{CONFIG.version} ###################"
        @_logify 5, "################### #{day}/#{month}/#{d.getFullYear()} - #{hours}:#{minutes}:#{seconds} #########################"

        if @secure
            app = https.createServer { key: fs.readFileSync(@ssl_key), cert: fs.readFileSync(@ssl_cert), ca: fs.readFileSync(@ssl_ca) }, @_handler
        else
            app = http.createServer @_handler

        server = app.listen @port, @host

        # enable transports
        @io = require('socket.io')(app, {
            transports: @mode,
            pingInterval: 10000,
            pingTimeout: 5000,
            cookie: @cookie
        })
        
        ns = {}

        # Register each different services by its namespace
        for service_name, service of @service_list
            if @login
                ns[service_name] = @io.of "/#{@login}/#{service_name}"
            else
                ns[service_name] = @io.of "/#{service_name}"

            # Ensure namespace conditions are met
            ns[service_name].use (socket, next) =>
                next()

            # get ready for connection
            ns[service_name].use @_handleEvents(ns[service_name], service_name)
            @_logify 6, "[*] service #{service_name} registered..."

        if @channel_list and @channel_list.length > 0
            # Register all channels by their room
            @io.sockets.on 'connection', @_handleEvents(io.sockets, 'global')
        
        @_logify 5, "[*] Starting server on #{@host}:#{@port} ..."
        @io.listen server
    
    # Allow sending message of specific service from external method
    interact: ({service, room, method, data}={}) ->
        ns = @io.of(service ||"/")
        sockets = if room then ns.in(room) else ns
        sockets.emit method, data

    # Once a client is connected, get ready to handle his events
    _handleEvents: (ns, service_name) ->
        (socket, next) =>
            @_logify 5, "[*] received connection for service #{service_name}"
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
                                    namespace: ns
                next()

    # On a specific event call the appropriate method of object
    _handleCallback: ({service, method, socket, namespace}) ->
        (data) =>
            try
                Fiber( =>
                    @_logify 6, "[*] call method #{method} of service #{service}"
                    @service_list[service][method] socket, data
                ).run()
            # Catch remaining errors
            catch err
                console.log "[!] Error while calling #{method}: #{err}"
            
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

