(function() {
  var InteractService;

  module.exports = InteractService = class InteractService {
    constructor(app) {
      this.app = app;
    }

    restricted(socket) {
      return socket.join('test');
    }

  };

}).call(this);
