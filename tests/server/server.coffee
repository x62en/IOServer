Server      = require '../../ioserver'
ChatService = require './chatService'
CoreService = require './coreService'

app = new Server
        verbose: 'DEBUG'
        host: 'localhost'
        port: 8080
        share: '../client'

app.addService
    name:  'core'
    service:   CoreService

app.addService
    name:  'chat'
    service:   ChatService

app.start()