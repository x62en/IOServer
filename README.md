# IOServer

Setup a damn simple Socket.io server using coffeescript.

This will launch a server on port specified (default: 8080) and will register all method of the class set as service, except ones starting by '_' (underscore).
These registrated methods will then be accessible as standard socket.io event:
```coffeescript
  socket.emit 'method_name', data
```


## Install

Install through npm
  ```bash
    npm install ioserver
  ```
  
## Usage

Require the module using coffeescript
  ```coffeescript
    app = require 'ioserver'
  ```

Add services using
  ```coffeescript
    app.addService
      name: 'service_name'
      service: Service_Class
  ```

Start the server
  ```coffeescript
    app.start()
  ```
  
You can also interact directly with a method in specific namespace using
  ```coffeescript
    app.interact
      service: 'service_name'
      method: 'method_name'
      data: data
  ```
