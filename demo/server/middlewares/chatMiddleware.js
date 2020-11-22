// Generated by CoffeeScript 2.5.1
(function() {
  var ChatMiddleware;

  module.exports = ChatMiddleware = class ChatMiddleware {
    // Requested function used by IOServer
    handle(app) {
      this.app = app;
      return (socket, next) => {
        var err, sid;
        try {
          sid = socket.handshake.auth.token;
          // Add socket.id in session
          this.app.sessions.add(sid, socket.id);
        } catch (error) {
          err = error;
          return next(new Error(err));
        }
        try {
          this._checkSessionAuthentified(sid);
          this._registeredUser(sid);
        } catch (error) {
          err = error;
          return next(new Error(err));
        }
        return next();
      };
    }

    _checkSessionAuthentified(sid) {
      if (!this.app.sessions.is_auth(sid)) {
        throw 'User is not authentified';
      }
    }

    _registeredUser(sid) {
      if (!this.app.users.is_registered(sid)) {
        throw 'User is not registered';
      }
    }

  };

}).call(this);