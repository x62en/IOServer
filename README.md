# IOServer

[![NPM](https://nodei.co/npm/ioserver.png?compact=true)](https://nodei.co/npm/ioserver/)

[![Downloads per month](https://img.shields.io/npm/dm/ioserver.svg?maxAge=2592000)](https://www.npmjs.org/package/ioserver)
[![npm version](https://img.shields.io/npm/v/ioserver.svg)](https://www.npmjs.org/package/ioserver)
[![Build Status](https://travis-ci.org/x42en/IOServer.svg?branch=master)](https://travis-ci.org/x42en/IOServer)
[![Known Vulnerabilities](https://snyk.io/test/github/x42en/ioserver/badge.svg)](https://snyk.io/test/github/x42en/ioserver)


Damn simple way to setup your [Socket.io](http://socket.io) server using coffeescript.

This will launch a server on port specified (default: 8080) and will register all method of the class set as service, except ones starting by '_' (underscore).
These registrated methods will then be accessible as standard client-side socket.io event:
```coffeescript
  socket.emit 'method_name', data
```
**Warning: Version 0.2.x switch parameters in server class, it was previously (data,socket), it is now (socket,data) in order to have some functions without anykind of data associated.**

## Install

Install with npm:
  ```bash
    npm install ioserver
  ```
  
## Basic Usage

Require the module:
  ```coffeescript
    app = require 'ioserver'
  ```

Add manager using:
  ```coffeescript
    app.addManager
      name:      'manager_name'
      manager:   ManagerClass
  ```

Add services using:
  ```coffeescript
    app.addService
      name:      'service_name'
      service:   ServiceClass
  ```

Start the server...
  ```coffeescript
    app.start()
  ```


## Extended usage

You can add services with Middlewares:
  ```coffeescript
    app.addService
      name:      'service_name'
      service:   ServiceClass
      middlewares: [
        AccessMiddleware
      ]
  ```
Middlewares are invoked at the socket connection to namespaces, they are usually used for restricting access, validate connection method and parameters.  

You can also interact directly with a method in specific namespace using:
  ```coffeescript
    app.interact
      service:  'service_name'
      method:   'method_name'
      data:     data
  ```

Common options are:
  ```coffeescript
    app = require 'ioserver'
      port:     8443                         # change listening port
      host:     '192.168.1.10'               # change listening host
      mode:     ['websocket']                # Set socket.io client
                                             # transport modes
                                             # default is:
                                             #  ['websocket','polling']
                                             # available methods are:
                                             #  ['websocket','htmlfile','polling','jsonp-polling']
      verbose:  'DEBUG'                      # set verbosity level
      share:    '/path/to/share'             # useful for:
                                             #  - letsencrypt compatibility
                                             #  - small server serving
      secure:   true                         # enable SSL listening
      ssl_ca:   '/path/to/ca/certificates'
      ssl_key:  '/path/to/server/key'
      ssl_cert: '/path/to/server/certificate'
      cookies: false                         # Enable cookie usage for
                                             # Socket.io v3

      cors: {                                # Set up CORS as requested
        origin: 'http://mydomain.com'        # in Socket.io v3
        methods: ['GET','POST']
      }
  ```
You can interact in a particular room of a service
  ```coffeescript
    app.interact
      service:  'service_name'
      room:     'room_name'
      method:   'method_name'
      data:     data
  ```

Or send to a specific user id
  ```coffeescript
    app.interact
      service:  'service_name'
      method:   'method_name'
      sid:      'specific_sid'
      data:     data
  ```

## Example

1. Write a simple class (singleChat.coffee)
  ```coffeescript
    module.exports = class SingleChat
      
      constructor: (@app) ->
      
      replay: (socket, text) ->
        console.log "Someone say: #{text}."
        socket.broadcast.emit 'message', text

      # Synchronous event are supported
      sync_replay: (socket, text, callback) ->
        console.log "Someone say: #{text}."
        callback text

      # All methods starting with '_' are meant private
      # and will not be published
      _notAccessible: (socket) ->
        console.error "You should not be here !!"
  ```

2. Start server-side ioserver process (server.coffee)
  ```coffeescript
    IOServer      = require 'ioserver'
    ChatService = require './singleChat'

    app = new IOServer()

    app.addService
      name:  'chat'
      service:   ChatService

    app.start()
  ```

3. Compile and run server
  ```bash
    coffee -c *.coffee
    node server.js
  ```

4. Write simple client wich interact with server class method as socket.io events
  ```coffeescript
    $           = require 'jquery'
    io          = require 'socket.io-client'
    NODE_SERVER = 'Your-server-ip'
    NODE_PORT   = 'Your-server-port' # Default 8080

    socket = io.connect "http://#{NODE_SERVER}:#{NODE_PORT}/chat"
    
    # When server emit action
    socket.on 'message', msg, ->
      $('.message_list').append "<div class='message'>#{msg}</div>"

    # Jquery client action
    $('button.send').on 'click', ->
      msg = $('input[name="message"]').val()
      socket.emit 'replay', msg
    
    # You can also use callback for synchronous actions
    $('button.send').on 'click', ->
      msg = $('input[name="message"]').val()
      socket.emit 'sync_replay', msg, (data) ->
        $('.message_list').append "<div class='message'>#{data}</div>"

  ```
For further case study you can also check de demo Chat application...  
(link provided in few ~~days~~ weeks ;) )

## Developers

If you want to contribute to this project you are more than welcome !  

### Run tests
```bash
npm test
```

**Please use Coffeescript for development language**  

### Compilation

Use coffeescript to compile your tests
```bash
coffee -wc ./test
```

Use coffeescript to compile your changes in IOServer
```bash
coffee --no-header -w --output dist/ --compile src/
```

### Publish

The NPM publishing is automated, just commit (or better merge) into master with comment 'Release v1.0.x' in order to publish corresponding package in NPM.

## TODO
* write better doc
* publish chat demo example
* improve unit tests for complete coverage (HTTPS / restricted method / interact function)
