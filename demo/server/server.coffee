IOServer      = require '../../ioserver'

CoreMiddleware = require './middlewares/coreMiddleware'
ChatMiddleware = require './middlewares/chatMiddleware'

SessionManager = require './managers/sessionManager'
UserManager    = require './managers/userManager'
MessageManager = require './managers/messageManager'

ChatService    = require './services/chatService'
CoreService    = require './services/coreService'

app = new IOServer
        verbose: 'DEBUG'
        host: 'localhost'
        port: 8080
        share: "#{__dirname}/../client"

# Add managers used by all entities
app.addManager
    name: 'sessions'
    manager: SessionManager

app.addManager
    name: 'users'
    manager: UserManager

app.addManager
    name: 'messages'
    manager: MessageManager

# Add socket.io services
app.addService
    name:  'core'
    service:   CoreService
    middlewares: [
        CoreMiddleware
    ]

app.addService
    name:  'chat'
    service:   ChatService
    middlewares: [
        ChatMiddleware
    ]

# Start application
app.start()
