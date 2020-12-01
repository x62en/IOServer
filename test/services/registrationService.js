(function() {
  var RegistrationService;

  module.exports = RegistrationService = class RegistrationService {
    constructor(app) {
      this.app = app;
    }

    _get_session(sid) {
      // Retrieve session ID
      return this.app.sessions.get(sid);
    }

    register(socket, data, callback) {
      var msg, sid;
      sid = this._get_session(socket.id);
      // Simulate authentication
      this.app.sessions.auth(sid, true);
      // Build answer
      msg = {
        status: 'ok',
        msg: 'Registration is OK!',
        sessid: sid
      };
      // Use callback for sync events
      return callback(msg);
    }

  };

}).call(this);
