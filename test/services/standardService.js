(function() {
  var IOServerError, StandardService;

  ({IOServerError} = require(`${__dirname}/../../build/ioserver`));

  module.exports = StandardService = class StandardService {
    constructor(app) {
      this.app = app;
    }

    _get_session(sid) {
      // Retrieve session ID
      return this.app.sessions.get(sid);
    }

    
      // Socket.io events
    hello(socket, data) {
      return socket.emit('answer', {
        status: 'ok',
        msg: `Hello ${data}!`
      });
    }

    sync_hello(socket, data, callback) {
      return callback({
        status: 'ok',
        msg: `Hello ${data}!`
      });
    }

    errored(socket, data) {
      throw 'I can not run';
    }

    errored_typed(socket, data) {
      throw new IOServerError('Custom error message', 3);
    }

    _forbidden(socket, data) {
      console.error('You should not be here !!');
      return socket.emit('forbidden call', 'OH NO!');
    }

  };

}).call(this);
