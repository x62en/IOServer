# Copyright [2014] 
# @Email: x62en (at) users (dot) noreply (dot) github (dot) com
# @Author: Ben Mz

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

fs = require('fs')
Server  = require('socket.io')
http = require('http')
https = require('https')

PORT    = 8080
HOST    = 'localhost'
LOG_LEVEL = ['EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTIFICATION','INFORMATION','DEBUG']
        

module.exports = class IOServer
    # Define the variables used by the server
    constructor: ({host, port, login, verbose, secure, ssl_ca, ssl_cert, ssl_key}) ->
        @host = if host then host else HOST
        @port = if port then port else PORT
        @login = if login then login else null
        @verbose = if verbose and LOG_LEVEL.indexOf(verbose.toUpperCase()) then LOG_LEVEL.indexOf(verbose.toUpperCase()) else 3
        @secure = if secure then secure else false

        @ssl_ca = if ssl_ca then ssl_ca else null
        @ssl_cert = if ssl_cert then ssl_cert else null
        @ssl_key = if ssl_key then ssl_key else null

        @service_list = {}
        @method_list = {}

    # Allow to register easily a class to this server
    # this class will be bind to a specific namespace
    addService: ({name, service}) ->
        if name? and (name.length > 2) and service? and service.prototype?
            @service_list[name] = new service()

            # list methods of object... it will be the list of io actions
            @method_list[name] = @_dumpMethods service
        else
            @_logify 3 ,"#[!] Service name MUST be longer than 2 characters"

    _handler: (req, res) ->
        res.writeHead 200;
        res.end "Hi, I'm a socket-io server."

    # Launch socket IO and get ready to handle events on connection
    start: () ->
        if @verbose
            d = new Date()
            day = d.getDate()
            month = d.getMonth()
            year = d.getFullYear()
            hours = d.getHours()
            minutes = d.getMinutes()
            seconds = d.getSeconds()
            hours = if hours < 10 then "0#{hours}" else "#{hours}"
            minutes = if minutes < 10 then ":0#{minutes}" else ":#{minutes}"
            seconds = if seconds < 10 then ":0#{seconds}" else ":#{seconds}"
            @_logify 0, "################### #{day}/#{month}/#{year} - #{hours}#{minutes}#{seconds} #########################"
            @_logify 0, "#[*] Starting server on #{@host}:#{@port} ..."

        if @secure
            app = https.createServer {key: @ssl_key, cert: @ssl_cert, ca: @ssl_ca}, @_handler
        else
            app = http.createServer @_handler

        app.listen @port, @host
        @io = Server.listen(app)

        @io.enable('browser client minification');  # send minified client
        @io.enable('browser client etag');          # apply etag caching logic based on version number
        @io.enable('browser client gzip');          # gzip the file
        @io.set('log level', 1);                    # reduce logging

        # enable all transports
        @io.set('transports', [
            'websocket'
            'htmlfile'
            'xhr-polling'
            'jsonp-polling'
        ])
        
        ns = {}

        # Register each different services by its namespace
        for service_name, service of @service_list
            if @login?
                ns[service_name] = @io.of "/#{@login}/#{service_name}"
            else
                ns[service_name] = @io.of "/#{service_name}"
            
            @_logify 6, "#[*] service #{service_name} registered..."
            # get ready for connection
            ns[service_name].on 'connection', @_handleEvents(ns[service_name], service_name)

        if @channel_list? and @channel_list.length > 0
            # Register all channels by their room
            io.sockets.on 'connection', @_handleEvents(io.sockets, 'global')
    
    # Allow sending message of specific service from external method
    interact: ({service, room, method, data}={}) ->
        @_findClientsSocket
            room: room
            service: service
            cb: (connectedSockets) =>
                if connectedSockets?
                    for i, socket of connectedSockets
                        # avoid undefined
                        if socket?
                            socket.emit method, data

    # Once a client is connected, get ready to handle his events
    _handleEvents: (ns, service_name) ->
        (socket) =>
            @_logify 5, "#[*] received connection for service #{service_name}"
            for index, action of @method_list[service_name]
                # does not listen for private methods
                if action.substring(0,1) is '_'
                    continue
                # do not listen for constructor method
                if action is 'constructor'
                    continue
                @_logify 7, "#[*] method #{action} of #{service_name} listening..."
                socket.on action, @_handleCallback
                                    service: service_name
                                    method: action
                                    socket: socket
                                    namespace: ns

    # On a specific event call the appropriate method of object
    _handleCallback: ({service, method, socket, namespace}) ->
        (data) =>
            @_logify 7, "#[*] call method #{method} of service #{service}"
            @service_list[service][method] data, socket

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

    _findClientsSocket: ({service, room, cb}={}) ->
        res = []
        ns = @io.of(service ||"/")

        if ns? and ns.connected?
            for id, i of ns.connected
                if room in Object.keys(ns.connected[id].rooms)
                    @_logify 7, "send notif #{service} to #{id} in #{room}"
                    res.push ns.connected[id]
        cb res

    _logify: (level, text) ->
        if level <= @verbose
            if level <= 4
                console.error text
            else
                console.log text

