(function() {
  //###################################################
  //         IOServer - v0.3.3                        #
  //                                                  #
  //         Damn simple socket.io server             #
  //###################################################
  //             -    Copyright 2020    -             #
  //                                                  #
  //   License: Apache v 2.0                          #
  //   @Author: Ben Mz                                #
  //   @Email: 0x42en (at) users.noreply.github.com   #
  //                                                  #
  //###################################################

  // Licensed under the Apache License, Version 2.0 (the "License");
  // you may not use this file except in compliance with the License.
  // You may obtain a copy of the License at

  //     http://www.apache.org/licenses/LICENSE-2.0

  // Unless required by applicable law or agreed to in writing, software
  // distributed under the License is distributed on an "AS IS" BASIS,
  // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  // See the License for the specific language governing permissions and
  // limitations under the License.
  var CONFIG, Fiber, HOST, IOServer, LOG_LEVEL, PORT, Server, TRANSPORTS, crypto, fs, http, https,
    indexOf = [].indexOf;

  fs = require('fs');

  Server = require('socket.io');

  http = require('http');

  https = require('https');

  Fiber = require('fibers');

  crypto = require('crypto');

  CONFIG = require('./package.json');

  PORT = 8080;

  HOST = 'localhost';

  LOG_LEVEL = ['EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR', 'WARNING', 'NOTIFICATION', 'INFORMATION', 'DEBUG'];

  TRANSPORTS = ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'];

  module.exports = IOServer = class IOServer {
    // Define the variables used by the server
    constructor({host, port, login, cookie, verbose, share, secure, ssl_ca, ssl_cert, ssl_key, mode}) {
      var e, i, m, ref, ref1, ref2;
      // Allow your small server to share some stuff
      this._handler = this._handler.bind(this);
      this.host = host ? String(host) : HOST;
      try {
        this.port = port ? Number(port) : PORT;
      } catch (error) {
        e = error;
        throw new Error('Invalid port.');
      }
      this.share = share ? String(share) : null;
      this.login = login ? String(login) : null;
      this.cookie = cookie ? Boolean(cookie) : false;
      this.verbose = (ref = String(verbose).toUpperCase(), indexOf.call(LOG_LEVEL, ref) >= 0) ? String(verbose).toUpperCase() : 'ERROR';
      
      // Process transport mode options
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
        this.mode.push('polling');
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

    // Allow to register easily a class to this server
    // this class will be bind to a specific namespace
    addService({name, service}) {
      var e;
      if (name && (name.length > 2) && service && service.prototype) {
        try {
          this.service_list[name] = new service();
        } catch (error) {
          e = error;
          if (`${e}`.substring('yield() called with no fiber running') !== -1) {
            console.error("[!] Error: you are NOT allowed to use fiberized function in constructor...");
          } else {
            console.error(`[!] Error while instantiate ${name} -> ${e}`);
          }
        }
        // list methods of object... it will be the list of io actions
        return this.method_list[name] = this._dumpMethods(service);
      } else {
        return this._logify(3, "#[!] Service name MUST be longer than 2 characters");
      }
    }

    // Get Instance running
    getInstance(name) {
      return this.service_list[name];
    }

    _generateAcceptValue(acceptKey) {
      return crypto.createHash('sha1').update(acceptKey + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', 'binary').digest('base64');
    }

    _handler(req, res) {
      var file, files, j, len, readStream, results;
      if (req.headers['upgrade'] !== 'websocket') {
        if (this.share) {
          files = fs.readdirSync(this.share);
          res.writeHead(200);
          if (!(files.length > 0)) {
            res.end('Shared path empty.');
          }
          results = [];
          for (j = 0, len = files.length; j < len; j++) {
            file = files[j];
            readStream = fs.createReadStream(`${this.share}/${file}`);
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
      }
    }

    // else
    //     # Read the websocket key provided by the client: 
    //     acceptKey = req.headers['sec-websocket-key']; 
    //     # Generate the response value to use in the response: 
    //     hash = @_generateAcceptValue(acceptKey); 
    //     # Write the HTTP response into an array of response lines: 
    //     responseHeaders = [ 'HTTP/1.1 101 Web Socket Protocol Handshake', 'Upgrade: WebSocket', 'Connection: Upgrade', 'Sec-WebSocket-Accept': hash ]; 
    //     # Write the response back to the client socket, being sure to append two 
    //     # additional newlines so that the browser recognises the end of the response 
    //     # header and doesn't continue to wait for more header data:
    //     res.writeHead 200
    //     res.write responseHeaders.join('\r\n') + '\r\n\r\n'

      // Launch socket IO and get ready to handle events on connection
    start() {
      var app, d, day, hours, minutes, month, ns, ref, seconds, server, service, service_name;
      d = new Date();
      day = d.getDate() < 10 ? `0${d.getDate()}` : d.getDate();
      month = d.getMonth() < 10 ? `0${d.getMonth()}` : d.getMonth();
      hours = d.getHours() < 10 ? `0${d.getHours()}` : d.getHours();
      minutes = d.getMinutes() < 10 ? `0${d.getMinutes()}` : d.getMinutes();
      seconds = d.getSeconds() < 10 ? `0${d.getSeconds()}` : d.getSeconds();
      this._logify(4, `################### IOServer v${CONFIG.version} ###################`);
      this._logify(5, `################### ${day}/${month}/${d.getFullYear()} - ${hours}:${minutes}:${seconds} #########################`);
      if (this.secure) {
        app = https.createServer({
          key: fs.readFileSync(this.ssl_key),
          cert: fs.readFileSync(this.ssl_cert),
          ca: fs.readFileSync(this.ssl_ca)
        }, this._handler);
      } else {
        app = http.createServer(this._handler);
      }
      server = app.listen(this.port, this.host);
      this._logify(5, `[*] Starting server on ${this.host}:${this.port} ...`);
      // enable transports
      this.io = require('socket.io')(server, {
        transports: this.mode,
        pingInterval: 10000,
        pingTimeout: 5000,
        cookie: this.cookie
      });
      ns = {};
      ref = this.service_list;
      // Register each different services by its namespace
      for (service_name in ref) {
        service = ref[service_name];
        if (this.login) {
          ns[service_name] = this.io.of(`/${this.login}/${service_name}`);
        } else {
          ns[service_name] = this.io.of(`/${service_name}`);
        }
        // Ensure namespace conditions are met
        ns[service_name].use((socket, next) => {
          return next();
        });
        // get ready for connection
        ns[service_name].use(this._handleEvents(ns[service_name], service_name));
        this._logify(6, `[*] service ${service_name} registered...`);
      }
      if (this.channel_list && this.channel_list.length > 0) {
        // Register all channels by their room
        return this.io.sockets.on('connection', this._handleEvents(io.sockets, 'global'));
      }
    }

    // Allow sending message of specific service from external method
    interact({service, room, method, data} = {}) {
      var ns, sockets;
      ns = this.io.of(service || "/");
      sockets = room ? ns.in(room) : ns;
      return sockets.emit(method, data);
    }

    // Once a client is connected, get ready to handle his events
    _handleEvents(ns, service_name) {
      return (socket, next) => {
        var action, index, ref, results;
        this._logify(5, `[*] received connection for service ${service_name}`);
        ref = this.method_list[service_name];
        results = [];
        for (index in ref) {
          action = ref[index];
          // does not listen for private methods
          if (action.substring(0, 1) === '_') {
            continue;
          }
          // do not listen for constructor method
          if (action === 'constructor') {
            continue;
          }
          this._logify(6, `[*] method ${action} of ${service_name} listening...`);
          socket.on(action, this._handleCallback({
            service: service_name,
            method: action,
            socket: socket,
            namespace: ns
          }));
          results.push(next());
        }
        return results;
      };
    }

    // On a specific event call the appropriate method of object
    _handleCallback({service, method, socket, namespace}) {
      return (data) => {
        var err;
        try {
          return Fiber(() => {
            this._logify(6, `[*] call method ${method} of service ${service}`);
            return this.service_list[service][method](socket, data);
          }).run();
        } catch (error) {
          // Catch remaining errors
          err = error;
          return console.log(`[!] Error while calling ${method}: ${err}`);
        }
      };
    }

    
      // Based on Kri-ban solution
    // http://stackoverflow.com/questions/7445726/how-to-list-methods-of-inherited-classes-in-coffeescript-or-javascript
    // Thanks ___ ;)
    _dumpMethods(klass) {
      var k, names, result;
      result = [];
      k = klass.prototype;
      while (k) {
        names = Object.getOwnPropertyNames(k);
        result = result.concat(names);
        k = Object.getPrototypeOf(k);
        if (!Object.getPrototypeOf(k)) { // avoid listing Object properties
          break;
        }
      }
      return this._unique(result).sort();
    }

    _unique(arr) {
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
    }

    _logify(level, text) {
      var current_level;
      current_level = LOG_LEVEL.indexOf(this.verbose);
      if (level <= current_level) {
        if (level <= 4) {
          return console.error(text);
        } else {
          return console.log(text);
        }
      }
    }

  };

}).call(this);
