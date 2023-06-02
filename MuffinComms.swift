import Foundation
import WebKit

class MuffinComms: NSObject, WKScriptMessageHandler {
  typealias CommsCallback = (Any) -> CommsResult
  
  enum CommsResult {
    case ok(_: Data)
    case error(_: String)
  }
  class CommsError: Error {
    var message: String
    init(message msg: String) {
      message = msg
    }
  }
  
  init(contentController ucc: WKUserContentController) {
    super.init()
    ucc.add(self, name: "muffinComms")
  }
  
  private var callbacks: [String: CommsCallback] = [:]
  public var webView: WKWebView? = nil
  
  public func addCallback(_ message: String, callback: @escaping CommsCallback) {
    guard callbacks[message] == nil else {
      print("[MuffinComms] Duplicate registration of callback for message '\(message)'. Second handler not registered")
      return
    }
    callbacks[message] = callback
  }
  
  private func dispatchError(message: String) {
    print("[MuffinComms] Error dispatching callback: \(message)")
    guard let wv = webView else { return }
    guard let base64 = message.data(using: .utf8)?.base64EncodedString() else {
      print("[MuffinComms] Failed to dispatch error: Could not encode error")
      return
    }
    let script = "console.error('[MuffinComms] Error dispatching callback: ' + atob('\(base64)'))"
    wv.evaluateJavaScript(script)
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let wv = webView else {
      print("[MuffinComms] MuffinComms.webView is nil!")
      return
    }
    
    guard let messageBody = message.body as? String else {
      dispatchError(message: "Malformed message body")
      return
    }
    
    let callbackResult = dispatchCallback(message: messageBody)
    switch callbackResult {
      case .failure(let commsError):
        dispatchError(message: commsError.message)
        
      case .success(let (id, result)):
        switch result {
          case .ok(let response):
            wv.evaluateJavaScript("MuffinComms._webkitMessage(\(id), atob('\(response.base64EncodedString())'))", completionHandler: nil)
          case .error(let error):
            dispatchError(message: error)
        }
    }
  }
  
  private func dispatchCallback(message: String) -> Result<(Int, CommsResult), CommsError> {
    guard let messageData = message.data(using: .utf8) else {
      return .failure(CommsError(message: "Could not parse message data as UTF8 ('\(message)')"))
    }
    guard let json = try? JSONSerialization.jsonObject(with: messageData) else {
      return .failure(CommsError(message: "Could not parse JSON '\(message)'"))
    }
    guard let jsonDict = json as? [String: Any] else {
      return .failure(CommsError(message: "Could not parse JSON '\(message)'"))
    }
    guard let jsonMessage = jsonDict["message"] as? String else {
      return .failure(CommsError(message: "Malformed request"))
    }
    guard let jsonData = jsonDict["data"] else {
      return .failure(CommsError(message: "Malformed request"))
    }
    guard let jsonId = jsonDict["id"] as? Int else {
      return .failure(CommsError(message: "Malformed request"))
    }
    guard let callback = callbacks[jsonMessage] else {
      return .failure(CommsError(message: "Missing callback '\(jsonMessage)'"))
    }
    return .success((jsonId, callback(jsonData)))
  }
}
