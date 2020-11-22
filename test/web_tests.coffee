# Import required packages
IOServer        = require '../ioserver'

# Import Applications entities
SessionManager    = require './managers/sessionManager'
AccessMiddleware  = require './middlewares/accessMiddleware'
PrivateMiddleware = require './middlewares/privateMiddleware'

# Import socket.io event classes
StandardService     = require './services/standardService'
RegistrationService = require './services/registrationService'
PrivateService      = require './services/privateService'

# Setup global vars
HOST = '127.0.0.1'
PORT = 8000

# Instanciate IOServer
app = new IOServer
        verbose: 'DEBUG'
        host: HOST
        port: PORT
        share: "#{__dirname}/public"

# Add session manager used to access private namespace
app.addManager
    name: 'sessions'
    manager: SessionManager

# Add listening service on global namespace '/'
app.addService
    service: StandardService

# Add named listening service on '/registration'
app.addService
    name: 'registration'
    service: RegistrationService
    middlewares: [
        AccessMiddleware
    ]

# Add restricted service on '/private' namespace
# Access is controlled in middleware
app.addService
    name: 'private'
    service: PrivateService
    middlewares: [
        AccessMiddleware,
        PrivateMiddleware
    ]

console.log "Open your browser on http://#{HOST}:#{PORT} for details"
app.start()