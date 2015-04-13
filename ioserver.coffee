_		= require 'lodash'
Server	= require('socket.io')

PORT 	= 8080
HOST 	= 'localhost'

module.exports = class IOServer
	# Define the variables used by the server
	constructor: ({host, port, login}={}) ->
		@host = if host? then host else HOST
		@port = if port? then port else PORT
		@login = if login? then login else null
		
		@service_list = {}
		@method_list = {}

	# Allow to register easily a class to this server
	# this class will be bind to a specific namespace
	addService: ({name, service}={}) ->
		if name? and name.length > 2
			@service_list[name] = new service()

			# list methods of object... it will be the list of io actions
			@method_list[name] = _.functions(@service_list[name])
		else
			console.error "#[!] Service name MUST be longer than 2 characters"

	# Launch socket IO and get ready to handle events on connection
	start: () ->
		date = @_now()
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
			
			console.log "#[+] service #{service_name} registered..."
			# get ready for connection
			ns[service_name].on 'connection', @handleEvents(ns[service_name], service_name)

		if @channel_list? and @channel_list.length > 0
			# Register all channels by their room
			io.sockets.on 'connection', @handleEvents(io.sockets, 'global')
		
	# Once a client is connected, get ready to handle his events
	handleEvents: (ns, service_name) ->
		(socket) =>
			console.log "#[+] received connection for service #{service_name}"
			for index, action of @method_list[service_name]
				# does not listen for private methods
				if action.substring(0,1) is '_'
					continue
				socket.on action, @handleCallback
									service: service_name
									method: action
									socket: socket
									namespace: ns

	# On a specific event call the appropriate method of object
	handleCallback: ({service, method, socket, namespace}={}) ->
		(data) =>
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
						console.log JSON.stringify ns.connected[id].rooms
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

