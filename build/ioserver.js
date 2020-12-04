(function() {
  //###################################################
  //         IOServer - v1.2.0                        #
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

  // Add required packages
  var HOST, IOServer, LOG_LEVEL, PORT, TRANSPORTS, VERSION, closer, http,
    indexOf = [].indexOf;

  http = require('http');

  closer = require('http-terminator');

  // Set global vars
  VERSION = '1.2.0';

  PORT = 8080;

  HOST = 'localhost';

  LOG_LEVEL = ['EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR', 'WARNING', 'NOTIFICATION', 'INFORMATION', 'DEBUG'];

  TRANSPORTS = ['websocket', 'htmlfile', 'xhr-polling', 'jsonp-polling'];

  module.exports = IOServer = class IOServer {
    // Define the variables used by the server
    constructor(options = {}) {
      var cookie, cors, e, host, i, m, middleware, mode, port, ref, ref1, ref2, verbose;
      // Allow sending message from external app
      this.sendTo = this.sendTo.bind(this);
      // Set default options
      ({verbose, host, port, cookie, mode, cors, middleware} = options);
      this.host = host ? String(host) : HOST;
      try {
        this.port = port ? Number(port) : PORT;
      } catch (error) {
        e = error;
        throw new Error('Invalid port.');
      }
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
      
      // Setup CORS since necessary in socket.io v3
      this.cors = (cors != null) && cors ? cors : {};
      if (!this.cors.methods) {
        this.cors.methods = ['GET', 'POST'];
      }
      if (!this.cors.origin) {
        this.cors.origin = [`https://${this.host}`, `http://${this.host}`];
      }
      
      // Setup internal lists
      this.service_list = {};
      this.manager_list = {};
      this.method_list = {};
      this.middlewares = {};
      
      // Register the global app handle
      // that will be passed to all entities
      this.appHandle = {
        send: this.sendTo
      };
      this.server = null;
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

    addManager({name, manager}) {
      var err;
      if (!name) {
        throw "[!] Manager name is mandatory";
      }
      if (name && name.length < 2) {
        throw "[!] Manager name MUST be longer than 2 characters";
      }
      if (name === 'send') {
        throw "[!] Sorry this is a reserved name";
      }
      if (!(manager || manager.prototype)) {
        throw "[!] Manager MUST be a function";
      }
      try {
        // Register manager with handle reference
        return this.manager_list[name] = new manager(this.appHandle);
      } catch (error) {
        err = error;
        return this._logify(3, `[!] Error while instantiate ${name} -> ${err}`);
      }
    }

    // Allow to register easily a class to this server
    // this class will be bind to a specific namespace
    addService({name, service, middlewares}) {
      var err;
      if (!(service && service.prototype)) {
        throw "[!] Service function is mandatory";
      }
      
      // Allow global register for '/'
      if (!name) {
        name = '/';
      
      // Otherwise service must comply certain rules
      } else if (name.length < 2) {
        throw "[!] Service name MUST be longer than 2 characters";
      }
      try {
        this.service_list[name] = new service(this.appHandle);
      } catch (error) {
        err = error;
        this._logify(3, `[!] Error while instantiate ${name} -> ${err}`);
      }
      // list methods of object... it will be the list of io actions
      this.method_list[name] = this._dumpMethods(service);
      // Register middlewares if necessary
      return this.middlewares[name] = middlewares ? middlewares : [];
    }

    // Get service running
    getService(name) {
      return this.service_list[name];
    }

    // Launch socket IO and get ready to handle events on connection
    // Pass web server used for connections
    start(webapp) {
      var d, day, hours, j, len, manager, manager_name, mdwr, middleware, minutes, month, ns, ref, ref1, ref2, seconds, server, service, service_name;
      // If nothing set use standard module
      if (webapp == null) {
        webapp = http.createServer();
      }
      d = new Date();
      day = d.getDate() < 10 ? `0${d.getDate()}` : d.getDate();
      month = d.getMonth() < 10 ? `0${d.getMonth()}` : d.getMonth();
      hours = d.getHours() < 10 ? `0${d.getHours()}` : d.getHours();
      minutes = d.getMinutes() < 10 ? `0${d.getMinutes()}` : d.getMinutes();
      seconds = d.getSeconds() < 10 ? `0${d.getSeconds()}` : d.getSeconds();
      this._logify(4, `################### IOServer v${VERSION} ###################`);
      this._logify(5, `################### ${day}/${month}/${d.getFullYear()} - ${hours}:${minutes}:${seconds} #########################`);
      
      // Start web server
      this._logify(5, `[*] Starting server on https://${this.host}:${this.port} ...`);
      server = webapp.listen(this.port, this.host);
      // Start socket.io listener
      this.io = require('socket.io')(server, {
        transports: this.mode,
        cookie: this.cookie,
        cors: this.cors
      });
      ns = {};
      ref = this.manager_list;
      // Register all managers
      for (manager_name in ref) {
        manager = ref[manager_name];
        this._logify(6, `[*] register ${manager_name} manager`);
        this.appHandle[manager_name] = manager;
      }
      ref1 = this.service_list;
      // Register each different services by its namespace
      for (service_name in ref1) {
        service = ref1[service_name];
        ns[service_name] = service_name === '/' ? this.io.of('/') : this.io.of(`/${service_name}`);
        ref2 = this.middlewares[service_name];
        // Register middleware for namespace 
        for (j = 0, len = ref2.length; j < len; j++) {
          middleware = ref2[j];
          mdwr = new middleware();
          ns[service_name].use(mdwr.handle(this.appHandle));
        }
        // get ready for connection
        ns[service_name].on("connection", this._handleEvents(service_name));
        this._logify(6, `[*] service ${service_name} registered...`);
      }
      
      // Create terminator handler
      return this.stopper = closer.createHttpTerminator({server});
    }

    
      // Force server stop
    stop() {
      this._logify(6, "[*] Stopping server");
      if (this.stopper) {
        return this.stopper.terminate();
      }
    }

    sendTo({namespace, event, data, room = false, sid = false} = {}) {
      var ns, sockets;
      ns = this.io.of(namespace || "/");
      // Send event to specific sid if set
      if ((sid != null) && sid) {
        return ns.sockets.get(sid).emit(event, data);
      } else {
        // Restrict access to clients in room if set
        sockets = (room != null) && room ? ns.in(room) : ns;
        return sockets.emit(event, data);
      }
    }

    // Once a client is connected, get ready to handle his events
    _handleEvents(service_name) {
      return (socket, next) => {
        var action, index, ref, results;
        this._logify(5, `[*] received connection for service ${service_name}`);
        ref = this.method_list[service_name];
        
        // The register all user defined functions
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
          results.push(socket.on(action, this._handleCallback({
            service: service_name,
            method: action,
            socket: socket
          })));
        }
        return results;
      };
    }

    // On a specific event call the appropriate method of object
    _handleCallback({service, method, socket}) {
      return (data, callback) => {
        var err;
        this._logify(6, `[*] call method ${method} of service ${service}`);
        try {
          return this.service_list[service][method](socket, data, callback);
        } catch (error) {
          err = error;
          this._logify(5, `Error on ${service}:${method} execution: ${err}`);
          if (callback) {
            return callback({
              error: err
            });
          } else {
            return socket.emit('error', err);
          }
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

  };

}).call(this);

//# sourceMappingURL=ioserver.js.map
