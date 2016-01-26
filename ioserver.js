/****************************************************/
/*         IOServer - v0.1.7                        */
/*                                                  */
/*         Damn simple socket.io server             */
/****************************************************/
/*             -    Copyright 2014    -             */
/*                                                  */
/*   License: Apache v 2.0                          */
/*   @Author: Ben Mz                                */
/*   @Email: x62en (at) users.noreply.github.com    */
/*                                                  */
/****************************************************/

(function() {
  var HOST, IOServer, PORT, Server,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Server = require('socket.io');

  PORT = 8080;

  HOST = 'localhost';

  module.exports = IOServer = (function() {
    function IOServer(_arg) {
      var host, login, port, verbose;
      host = _arg.host, port = _arg.port, login = _arg.login, verbose = _arg.verbose;
      this.host = host != null ? host : HOST;
      this.port = port != null ? port : PORT;
      this.login = login != null ? login : null;
      this.verbose = verbose != null ? verbose : false;
      this.service_list = {};
      this.method_list = {};
    }

    IOServer.prototype.addService = function(_arg) {
      var name, service;
      name = _arg.name, service = _arg.service;
      if ((name != null) && (name.length > 2) && (service != null) && (service.prototype != null)) {
        this.service_list[name] = new service();
        return this.method_list[name] = this._dumpMethods(service);
      } else {
        return this._logify("#[!] Service name MUST be longer than 2 characters");
      }
    };

    IOServer.prototype.start = function() {
      var d, day, hours, minutes, month, ns, seconds, service, service_name, year, _ref;
      if (this.verbose) {
        d = new Date();
        day = d.getDate();
        month = d.getMonth();
        year = d.getFullYear();
        hours = d.getHours();
        minutes = d.getMinutes();
        seconds = d.getSeconds();
        hours = hours < 10 ? "0" + hours : "" + hours;
        minutes = minutes < 10 ? ":0" + minutes : ":" + minutes;
        seconds = seconds < 10 ? ":0" + seconds : ":" + seconds;
        this._logify("################### " + day + "/" + month + "/" + year + " - " + hours + minutes + seconds + " #########################");
        this._logify("#[*] Starting server on port: " + this.port + " ...");
      }
      this.io = Server.listen(this.port);
      ns = {};
      _ref = this.service_list;
      for (service_name in _ref) {
        service = _ref[service_name];
        if (this.login != null) {
          ns[service_name] = this.io.of("/" + this.login + "/" + service_name);
        } else {
          ns[service_name] = this.io.of("/" + service_name);
        }
        this._logify("#[*] service " + service_name + " registered...");
        ns[service_name].on('connection', this._handleEvents(ns[service_name], service_name));
      }
      if ((this.channel_list != null) && this.channel_list.length > 0) {
        return io.sockets.on('connection', this._handleEvents(io.sockets, 'global'));
      }
    };

    IOServer.prototype.interact = function(_arg) {
      var data, method, room, service, _ref;
      _ref = _arg != null ? _arg : {}, service = _ref.service, room = _ref.room, method = _ref.method, data = _ref.data;
      return this._findClientsSocket({
        room: room,
        service: service,
        cb: (function(_this) {
          return function(connectedSockets) {
            var i, socket, _results;
            if (connectedSockets != null) {
              _results = [];
              for (i in connectedSockets) {
                socket = connectedSockets[i];
                if (socket != null) {
                  _results.push(socket.emit(method, data));
                } else {
                  _results.push(void 0);
                }
              }
              return _results;
            }
          };
        })(this)
      });
    };

    IOServer.prototype._handleEvents = function(ns, service_name) {
      return (function(_this) {
        return function(socket) {
          var action, index, _ref, _results;
          _this._logify("#[*] received connection for service " + service_name);
          _ref = _this.method_list[service_name];
          _results = [];
          for (index in _ref) {
            action = _ref[index];
            if (action.substring(0, 1) === '_') {
              continue;
            }
            if (action === 'constructor') {
              continue;
            }
            _this._logify("#[*] method " + action + " of " + service_name + " listening...");
            _results.push(socket.on(action, _this._handleCallback({
              service: service_name,
              method: action,
              socket: socket,
              namespace: ns
            })));
          }
          return _results;
        };
      })(this);
    };

    IOServer.prototype._handleCallback = function(_arg) {
      var method, namespace, service, socket;
      service = _arg.service, method = _arg.method, socket = _arg.socket, namespace = _arg.namespace;
      return (function(_this) {
        return function(data) {
          _this._logify("#[*] call method " + method + " of service " + service);
          return _this.service_list[service][method](data, socket);
        };
      })(this);
    };

    IOServer.prototype._dumpMethods = function(klass) {
      var k, names, result;
      result = [];
      k = klass.prototype;
      while (k) {
        names = Object.getOwnPropertyNames(k);
        result = result.concat(names);
        k = Object.getPrototypeOf(k);
        if (!Object.getPrototypeOf(k)) {
          break;
        }
      }
      return this._unique(result).sort();
    };

    IOServer.prototype._unique = function(arr) {
      var hash, i, l, result;
      hash = {};
      result = [];
      i = 0;
      l = arr.length;
      while (i < l) {
        if (!hash.hasOwnProperty(arr[i])) {
          hash[arr[i]] = true;
          result.push(arr[i]);
        }
        ++i;
      }
      return result;
    };

    IOServer.prototype._findClientsSocket = function(_arg) {
      var cb, i, id, ns, res, room, service, _ref, _ref1;
      _ref = _arg != null ? _arg : {}, service = _ref.service, room = _ref.room, cb = _ref.cb;
      res = [];
      ns = this.io.of(service || "/");
      if ((ns != null) && (ns.connected != null)) {
        _ref1 = ns.connected;
        for (id in _ref1) {
          i = _ref1[id];
          if (__indexOf.call(Object.keys(ns.connected[id].rooms), room) >= 0) {
            this._logify("send notif " + service + " to " + id + " in " + room);
            res.push(ns.connected[id]);
          }
        }
      }
      return cb(res);
    };

    IOServer.prototype._logify = function(text) {
      if (this.verbose) {
        return console.log("" + text);
      }
    };

    return IOServer;

  })();

}).call(this);
