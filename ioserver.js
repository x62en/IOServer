/****************************************************/
/*         IOServer - v0.2.4                        */
/*                                                  */
/*         Damn simple socket.io server             */
/****************************************************/
/*             -    Copyright 2017    -             */
/*                                                  */
/*   License: Apache v 2.0                          */
/*   @Author: Ben Mz                                */
/*   @Email: 0x42en (at) gmail.com                  */
/*                                                  */
/****************************************************/

(function() {
  var CONFIG, Fiber, HOST, IOServer, LOG_LEVEL, PORT, Server, TRANSPORTS, fs, http, https,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  fs = require('fs');

  Server = require('socket.io');

  http = require('http');

  https = require('https');

  Fiber = require('fibers');

  CONFIG = require('./package.json');

  PORT = 8080;

  HOST = 'localhost';

  LOG_LEVEL = ['EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR', 'WARNING', 'NOTIFICATION', 'INFORMATION', 'DEBUG'];

  TRANSPORTS = ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'];

  module.exports = IOServer = (function() {
    function IOServer(arg) {
      var e, error, host, i, login, m, mode, port, ref, ref1, ref2, secure, share, ssl_ca, ssl_cert, ssl_key, verbose;
      host = arg.host, port = arg.port, login = arg.login, verbose = arg.verbose, share = arg.share, secure = arg.secure, ssl_ca = arg.ssl_ca, ssl_cert = arg.ssl_cert, ssl_key = arg.ssl_key, mode = arg.mode;
      this._handler = bind(this._handler, this);
      this.host = host ? String(host) : HOST;
      try {
        this.port = port ? Number(port) : PORT;
      } catch (error) {
        e = error;
        throw new Error('Invalid port.');
      }
      this.share = share ? String(share) : null;
      this.login = login ? String(login) : null;
      this.verbose = (ref = String(verbose).toUpperCase(), indexOf.call(LOG_LEVEL, ref) >= 0) ? String(verbose).toUpperCase() : 'ERROR';
      this.mode = [];
      if (mode) {
        if (ref1 = String(mode).toLowerCase(), indexOf.call(TRANSPORTS, ref1) >= 0) {
          this.mode.push(String(mode).toLowerCase());
        } else if (mode.constructor === Array) {
          for (i in mode) {
            m = mode[i];
            if (ref2 = String(m).toLowerCase(), indexOf.call(TRANSPORTS, ref2) >= 0) {
              this.mode.push(m);
            }
          }
        }
      } else {
        this.mode.push('websocket');
        this.mode.push('xhr-polling');
      }
      this.secure = secure ? Boolean(secure) : false;
      if (this.secure) {
        this.ssl_ca = ssl_ca ? String(ssl_ca) : null;
        this.ssl_cert = ssl_cert ? String(ssl_cert) : null;
        this.ssl_key = ssl_key ? String(ssl_key) : null;
      }
      this.service_list = {};
      this.method_list = {};
    }

    IOServer.prototype.addService = function(arg) {
      var e, error, name, service;
      name = arg.name, service = arg.service;
      if (name && (name.length > 2) && service && service.prototype) {
        try {
          this.service_list[name] = new service();
        } catch (error) {
          e = error;
          if (("" + e).substring('yield() called with no fiber running') !== -1) {
            console.error("[!] Error: you are NOT allowed to use fiberized function in constructor...");
          } else {
            console.error("[!] Error while instantiate " + name + " -> " + e);
          }
        }
        return this.method_list[name] = this._dumpMethods(service);
      } else {
        return this._logify(3, "#[!] Service name MUST be longer than 2 characters");
      }
    };

    IOServer.prototype.getInstance = function(name) {
      return this.service_list[name];
    };

    IOServer.prototype._handler = function(req, res) {
      var file, files, j, len, readStream, results;
      if (this.share) {
        files = fs.readdirSync(this.share);
        res.writeHead(200);
        if (!(files.length > 0)) {
          res.end('Shared path empty.');
        }
        results = [];
        for (j = 0, len = files.length; j < len; j++) {
          file = files[j];
          readStream = fs.createReadStream(this.share + "/" + file);
          readStream.on('open', function() {
            return readStream.pipe(res);
          });
          readStream.on('error', function(err) {
            res.writeHead(500);
            return res.end(err);
          });
          break;
        }
        return results;
      } else {
        res.writeHead(200);
        return res.end('Nothing shared.');
      }
    };

    IOServer.prototype.start = function() {
      var app, d, day, hours, minutes, month, ns, ref, seconds, service, service_name;
      d = new Date();
      day = d.getDate() < 10 ? "0" + (d.getDate()) : d.getDate();
      month = d.getMonth() < 10 ? "0" + (d.getMonth()) : d.getMonth();
      hours = d.getHours() < 10 ? "0" + (d.getHours()) : d.getHours();
      minutes = d.getMinutes() < 10 ? "0" + (d.getMinutes()) : d.getMinutes();
      seconds = d.getSeconds() < 10 ? "0" + (d.getSeconds()) : d.getSeconds();
      this._logify(4, "################### IOServer v" + CONFIG.version + " ###################");
      this._logify(5, "################### " + day + "/" + month + "/" + (d.getFullYear()) + " - " + hours + ":" + minutes + ":" + seconds + " #########################");
      this._logify(5, "[*] Starting server on " + this.host + ":" + this.port + " ...");
      if (this.secure) {
        app = https.createServer({
          key: fs.readFileSync(this.ssl_key),
          cert: fs.readFileSync(this.ssl_cert),
          ca: fs.readFileSync(this.ssl_ca)
        }, this._handler);
      } else {
        app = http.createServer(this._handler);
      }
      app.listen(this.port, this.host);
      this.io = Server.listen(app);
      this.io.set('transports', this.mode);
      ns = {};
      ref = this.service_list;
      for (service_name in ref) {
        service = ref[service_name];
        if (this.login) {
          ns[service_name] = this.io.of("/" + this.login + "/" + service_name);
        } else {
          ns[service_name] = this.io.of("/" + service_name);
        }
        this._logify(6, "[*] service " + service_name + " registered...");
        ns[service_name].on('connection', this._handleEvents(ns[service_name], service_name));
      }
      if (this.channel_list && this.channel_list.length > 0) {
        return this.io.sockets.on('connection', this._handleEvents(io.sockets, 'global'));
      }
    };

    IOServer.prototype.interact = function(arg) {
      var data, method, ns, ref, room, service, sockets;
      ref = arg != null ? arg : {}, service = ref.service, room = ref.room, method = ref.method, data = ref.data;
      ns = this.io.of(service || "/");
      sockets = room ? ns["in"](room) : ns;
      return sockets.emit(method, data);
    };

    IOServer.prototype._handleEvents = function(ns, service_name) {
      return (function(_this) {
        return function(socket) {
          var action, index, ref, results;
          _this._logify(5, "[*] received connection for service " + service_name);
          ref = _this.method_list[service_name];
          results = [];
          for (index in ref) {
            action = ref[index];
            if (action.substring(0, 1) === '_') {
              continue;
            }
            if (action === 'constructor') {
              continue;
            }
            _this._logify(6, "[*] method " + action + " of " + service_name + " listening...");
            results.push(socket.on(action, _this._handleCallback({
              service: service_name,
              method: action,
              socket: socket,
              namespace: ns
            })));
          }
          return results;
        };
      })(this);
    };

    IOServer.prototype._handleCallback = function(arg) {
      var method, namespace, service, socket;
      service = arg.service, method = arg.method, socket = arg.socket, namespace = arg.namespace;
      return (function(_this) {
        return function(data) {
          var err, error;
          try {
            return Fiber(function() {
              _this._logify(6, "[*] call method " + method + " of service " + service);
              return _this.service_list[service][method](socket, data);
            }).run();
          } catch (error) {
            err = error;
            return console.log("[!] Error while calling " + method + ": " + err);
          }
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

    IOServer.prototype._logify = function(level, text) {
      var current_level;
      current_level = LOG_LEVEL.indexOf(this.verbose);
      if (level <= current_level) {
        if (level <= 4) {
          return console.error(text);
        } else {
          return console.log(text);
        }
      }
    };

    return IOServer;

  })();

}).call(this);
