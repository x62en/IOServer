(function() {
  var PrivateService;

  module.exports = PrivateService = class PrivateService {
    constructor(app) {
      this.app = app;
    }

    // Socket.io events
    message(socket, msg) {
      return socket.emit('private answer', `PRIVATE: ${msg}`);
    }

  };

}).call(this);
