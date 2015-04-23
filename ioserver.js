/****************************************************/
/*         IOServer - v0.1.5                        */
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
  var HOST, IOServer, PORT, Server;

  Server = require('socket.io');

  PORT = 8080;

  HOST = 'localhost';

  module.exports = IOServer = (function() {
    function IOServer(_arg) {
      var host, login, port, verbose, _ref;
      _ref = _arg != null ? _arg : {}, host = _ref.host, port = _ref.port, login = _ref.login, verbose = _ref.verbose;
      this.host = host != null ? host : HOST;
      this.port = port != null ? port : PORT;
      this.login = login != null ? login : null;
      this.verbose = verbose != null ? verbose : false;
      this.service_list = {};
      this.method_list = {};
    }

    IOServer.prototype.addService = function(_arg) {
      var name, service, _ref;
      _ref = _arg != null ? _arg : {}, name = _ref.name, service = _ref.service;
      if ((name != null) && name.length > 2) {
        this.service_list[name] = new service();
        return this.method_list[name] = this._dumpMethods(service);
      } else {
        return console.error("#[!] Service name MUST be longer than 2 characters");
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
        console.log("################### " + day + "/" + month + "/" + year + " - " + hours + minutes + seconds + " #########################");
        console.log("#[+] Starting server on port: " + this.port + " ...");
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
        if (this.verbose) {
          console.log("#[+] service " + service_name + " registered...");
        }
        ns[service_name].on('connection', this.handleEvents(ns[service_name], service_name));
      }
      if ((this.channel_list != null) && this.channel_list.length > 0) {
        return io.sockets.on('connection', this.handleEvents(io.sockets, 'global'));
      }
    };

    IOServer.prototype.handleEvents = function(ns, service_name) {
      return (function(_this) {
        return function(socket) {
          var action, index, _ref, _results;
          if (_this.verbose) {
            console.log("#[+] received connection for service " + service_name);
          }
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
            if (_this.verbose) {
              console.log("#[+] method " + action + " of " + service_name + " listening...");
            }
            _results.push(socket.on(action, _this.handleCallback({
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

    IOServer.prototype.handleCallback = function(_arg) {
      var method, namespace, service, socket, _ref;
      _ref = _arg != null ? _arg : {}, service = _ref.service, method = _ref.method, socket = _ref.socket, namespace = _ref.namespace;
      return (function(_this) {
        return function(data) {
          if (_this.verbose) {
            console.log("#[+] call method " + method + " of service " + service);
          }
          return _this.service_list[service][method](data, socket);
        };
      })(this);
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
      var cb, i, id, index, ns, res, room, service, _ref, _ref1;
      _ref = _arg != null ? _arg : {}, service = _ref.service, room = _ref.room, cb = _ref.cb;
      res = [];
      ns = this.io.of(service || "/");
      if (ns) {
        _ref1 = ns.connected;
        for (id in _ref1) {
          i = _ref1[id];
          if ((room != null) && room.length > 0) {
            index = ns.connected[id].rooms.indexOf(room);
            if (index !== -1) {
              res.push(ns.connected[id]);
            }
          } else {
            res.push(ns.connected[id]);
          }
        }
      }
      return cb(res);
    };

    return IOServer;

  })();

}).call(this);
