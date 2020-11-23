# Import required packages
should          = require('chai').should()
socketio_client = require 'socket.io-client'
IOServer        = require '../dist/ioserver'

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
PORT = 8080
end_point = "http://#{HOST}:#{PORT}"
opts = { forceNew: true }

# Instanciate IOServer
app = new IOServer
        host: HOST
        port: PORT

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

###################### UNIT TESTS ##########################
describe "IOServer simple HTTP working tests", ->

    # Set global timeout
    @timeout 4000

    before( () ->
        # Start server
        console.log "Start IOServer"
        app.start()
    )

    after( () ->
        # Stop server
        console.log "Stop IOServer"
        app.stop()
    )
    
    it 'Check public method', (done) ->
        socket_client = socketio_client(end_point, opts)
        socket_client.once 'answer', (data) ->
            data.should.be.an 'object'
            data.should.have.deep.property 'status'
            data.should.have.deep.property 'msg'
            
            data.status.should.be.equal 'ok'
            data.msg.should.be.equal 'Hello ABDEF!'
            
            socket_client.disconnect()
            done()
        socket_client.emit 'hello', 'ABDEF'
    
    it 'Check public method sync', (done) ->
        socket_client = socketio_client(end_point, opts)
        socket_client.emit 'sync_hello', 'ABDEF', (data) ->
            data.should.be.an 'object'
            data.should.have.deep.property 'status'
            data.should.have.deep.property 'msg'
            
            data.status.should.be.equal 'ok'
            data.msg.should.be.equal 'Hello ABDEF!'
            
            socket_client.disconnect()
            done()
    
    it 'Check public method error', (done) ->
        socket_client = socketio_client(end_point, opts)
        socket_client.on 'error', (data) ->
            data.should.be.a 'string'
            
            data.should.be.equal 'I can not run'
            
            socket_client.disconnect()
            done()
        socket_client.emit 'errored'
    
    it 'Check public method error sync', (done) ->
        socket_client = socketio_client(end_point, opts)
        socket_client.emit 'errored', null, (data) ->
            data.should.be.an 'object'
            data.should.have.deep.property 'error'
            
            data.error.should.be.equal 'I can not run'
            
            socket_client.disconnect()
            done()
    
    # it 'Check access forbidden method', (done) ->
    #     socket_client = socketio_client(end_point, opts)
    #     socket_client.emit '_forbidden', 'ABDEF'
    #     socket_client.once 'forbidden call', (data) ->
    #         console.error data
    #         socket_client.disconnect()
    #         done()
        
    #     socket_client.once 'error', (data) ->
    #         console.error data
    #         socket_client.disconnect()
    #         done()
    
    it 'Check registration method', (done) ->
        socket_client = socketio_client("#{end_point}/registration", opts)
        socket_client.emit 'register', 'ABDEF', (data) ->
            data.should.be.an 'object'
            data.should.have.deep.property 'status'
            data.should.have.deep.property 'msg'
            data.should.have.deep.property 'sessid'
            
            data.status.should.be.equal 'ok'
            data.msg.should.be.equal 'Registration is OK!'
            data.sessid.should.be.a 'string'
            
            socket_client.disconnect()
            done()
    
    it 'Check access private method', (done) ->
        socket_client = socketio_client("#{end_point}/registration", opts)
        socket_client.emit 'register', null, (data) ->
            data.should.be.an 'object'
            
            data.should.have.deep.property 'status'
            data.should.have.deep.property 'msg'
            data.should.have.deep.property 'sessid'
            
            data.status.should.be.equal 'ok'
            data.msg.should.be.equal 'Registration is OK!'
            data.sessid.should.be.a 'string'
            
            auth_client = socketio_client("#{end_point}/private", {query: {auth: data.sessid}})
            auth_client.emit 'message', 'area'
            auth_client.once 'private answer', (response) ->
                response.should.be.a 'string'
                response.should.be.equal 'PRIVATE: area'
            
            socket_client.disconnect()
            done()

#################### END UNIT TESTS #########################