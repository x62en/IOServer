// Generated by CoffeeScript 2.5.1
(function() {
  var CoreService;

  module.exports = CoreService = class CoreService {
    constructor(app) {
      this.app = app;
    }

    _validNickname(nickname) {
      if (nickname === void 0 || nickname === '') {
        throw 'Nickname can not be empty';
      }
      if (nickname.length < 3) {
        throw 'Nickname is too short';
      }
      if (nickname.length > 20) {
        throw 'Nickname is too long';
      }
    }

    _existsNickname(nickname) {
      if (this.app.users.exists(nickname)) {
        throw 'User already exists';
      }
    }

    // Socket.io events
    register(socket, data, callback) {
      var sessid, user;
      // Validations errors are handled by IOServer
      this._validNickname(data.nickname);
      this._existsNickname(data.nickname);
      
      // Retrieve session ID
      sessid = this.app.sessions.get(socket.id);
      // Register user
      console.log(`Register ${data.nickname}`);
      user = this.app.users.register(sessid, data.nickname, parseInt(data.imgid, 10));
      // Make user session authentified
      this.app.sessions.auth(sessid, true);
      
      // Return user data
      return callback(user);
    }

  };

}).call(this);
