const MuffinComms = {
  _callbacks: [],
  _webkitMessage: function(id, message) {
    MuffinComms._callbacks[id](message);
  },
  isAvailable: function() {
    return window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.muffinComms;
  },
  verifyAvailable: function() {
    if (!MuffinComms.isAvailable()) {
      throw "[MuffinComms] Could not complete the requested operation as the webkit service is not available";
    }
  },
  send: function(message, data, responseType="text") {
    MuffinComms.verifyAvailable();
    if (message === undefined) {
      throw "[MuffinComms] Message is undefined!";
    }
    if (data === undefined) {
      throw "[MuffinComms] Data is undefined!";
    }
    return new Promise(function(resolve) {
      let id = MuffinComms._callbacks.push(function(data) {
        if (responseType == "text") {
          resolve(data);
        } else if (responseType == "json") {
          resolve(JSON.parse(data));
        } else if (responseType == "arraybuffer") {
          const length = data.length;
          const buffer = new ArrayBuffer(length);
          const view = new Uint8Array(buffer);

          for (let i = 0; i < length; i++) {
            view[i] = data.charCodeAt(i);
          }

          resolve(buffer);
        } else {
          console.error(`[MuffinComms] Unsupported responseType '${responseType}'`);
        }
      }) - 1;
      window.webkit.messageHandlers.muffinComms.postMessage(JSON.stringify({message: message, data: data, id: id}));
    });
  },
};
