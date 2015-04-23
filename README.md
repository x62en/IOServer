# IOServer

[![NPM](https://nodei.co/npm/ioserver.png?compact=true)](https://nodei.co/npm/ioserver/)

Damn simple way to setup your [Socket.io](http://socket.io) server using coffeescript.

This will launch a server on port specified (default: 8080) and will register all method of the class set as service, except ones starting by '_' (underscore).
These registrated methods will then be accessible as standard client-side socket.io event:

```coffeescript
  socket.emit 'method_name', data
```


## Install

Install with npm:
  ```sh
    npm install ioserver
  ```
  
## Basic Usage

Require the module:
  ```coffeescript
    app = require 'ioserver'
  ```

Add services using:
  ```coffeescript
    app.addService
      name: 'service_name'
      service: Service_Class
  ```

Start the server...
  ```coffeescript
    app.start()
  ```


## Extended usage

You can also interact directly with a method in specific namespace using:
  ```coffeescript
    app.interact
      service: 'service_name'
      method: 'method_name'
      data: data
  ```

Common options are:
  ```coffeescript
    app = require 'ioserver'
      port: 8443       # change listening port

      # One day... socket.io
      # will allow us to specify a host, but for now...
      # host: 192.168.1.10
      
      # TODO: 
      #login: 'test'    # set login in all query based on socketID?
      #verbose: INFOS   # set verbosity level

  ```
You can interact in a particular room of a service
  ```coffeescript
    app.interact
      service:  'service_name'
      room:     'room_name'
      method:   'method_name'
      data: data
  ```

## TODO

### 1. implement log
### 2. set user identification