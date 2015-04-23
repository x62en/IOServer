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

Server	= require('socket.io')

PORT 	= 8080
HOST 	= 'localhost'
		

module.exports = class IOServer
	# Define the variables used by the server
	constructor: ({host, port, login, verbose}={}) ->
		@host = if host? then host else HOST
		@port = if port? then port else PORT
		@login = if login? then login else null
		@verbose = if verbose? then verbose else false

		@service_list = {}
		@method_list = {}

	# Allow to register easily a class to this server
	# this class will be bind to a specific namespace
	addService: ({name, service}={}) ->
		if name? and name.length > 2
			@service_list[name] = new service()

			# list methods of object... it will be the list of io actions
			@_dumpMethods(name)
		else
			console.error "#[!] Service name MUST be longer than 2 characters"

	# Launch socket IO and get ready to handle events on connection
	start: () ->
		date = @_now()
		if @verbose
			console.log "###################### #{date} #############################"
			console.log "#[+] Starting server on port: #{@port} ..."
		@io = Server.listen(@port)
		
		ns = {}

		# Register each different services by its namespace
		for service_name, service of @service_list
			if @login?
				ns[service_name] = @io.of "/#{@login}/#{service_name}"
			else
				ns[service_name] = @io.of "/#{service_name}"
			
			if @verbose
				console.log "#[+] service #{service_name} registered..."
			# get ready for connection
			ns[service_name].on 'connection', @handleEvents(ns[service_name], service_name)

		if @channel_list? and @channel_list.length > 0
			# Register all channels by their room
			io.sockets.on 'connection', @handleEvents(io.sockets, 'global')
		
	# Once a client is connected, get ready to handle his events
	handleEvents: (ns, service_name) ->
		(socket) =>
			if @verbose
				console.log "#[+] received connection for service #{service_name}"
			for index, action of @method_list[service_name]
				# does not listen for private methods
				if action.substring(0,1) is '_'
					continue
				# do not listen for constructor method
				if action is 'constructor'
					continue
				if @verbose
					console.log "#[+] method #{action} of #{service_name} listening..."
				socket.on action, @handleCallback
									service: service_name
									method: action
									socket: socket
									namespace: ns

	# On a specific event call the appropriate method of object
	handleCallback: ({service, method, socket, namespace}={}) ->
		(data) =>
			if @verbose
				console.log "#[+] call method #{method} of service #{service}"
			@service_list[service][method] data, socket

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

	# Thanks to Kri-ban
	# http://stackoverflow.com/questions/7445726/how-to-list-methods-of-inherited-classes-in-coffeescript-or-javascript
	# ___ ;)
	_dumpMethods: (name) ->
		@method_list[name] = []
		s = @method_list[name].prototype
		while k
			names = Object.getOwnPropertyNames(k)
			@method_list[name] = @method_list[name].concat(names)
			k = Object.getPrototypeOf(k)
			break if not Object.getPrototypeOf(k) # avoid listing Object properties
		@method_list[name] = @_unique(@method_list[name]).sort()

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

		if ns
			for id, i of ns.connected
				if room? and room.length > 0
					index = ns.connected[id].rooms.indexOf(room)
					unless index is -1
						res.push ns.connected[id]
				else
					res.push ns.connected[id]
		cb res


	_now: () ->
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
		return "#{day}/#{month}/#{year} - #{hours}#{minutes}#{seconds}"

