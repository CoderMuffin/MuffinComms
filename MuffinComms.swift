//
//  MuffinComms.swift
//  abcplayer
//
//  Created by Clive Williams on 30/05/2023.
//

import Foundation
import WebKit

class MuffinComms: NSObject, WKScriptMessageHandler {
  typealias CommsCallback = (Any) -> MuffinComms.CommsResult
  
  struct AnyCodable: Codable {
      let value: Any
      
      init(_ value: Any) {
          self.value = value
      }
      
      init(from decoder: Decoder) throws {
          let container = try decoder.singleValueContainer()
          
          if let intValue = try? container.decode(Int.self) {
              value = intValue
          } else if let doubleValue = try? container.decode(Double.self) {
              value = doubleValue
          } else if let boolValue = try? container.decode(Bool.self) {
              value = boolValue
          } else if let stringValue = try? container.decode(String.self) {
              value = stringValue
          } else if let nestedDict = try? container.decode([String: AnyCodable].self) {
              value = nestedDict
          } else if let nestedArray = try? container.decode([AnyCodable].self) {
              value = nestedArray
          } else if container.decodeNil() {
              value = NSNull()
          } else {
              throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
          }
      }
      
      func encode(to encoder: Encoder) throws {
          var container = encoder.singleValueContainer()
          
          switch value {
          case let intValue as Int:
              try container.encode(intValue)
          case let doubleValue as Double:
              try container.encode(doubleValue)
          case let boolValue as Bool:
              try container.encode(boolValue)
          case let stringValue as String:
              try container.encode(stringValue)
          case let nestedDict as [String: AnyCodable]:
              try container.encode(nestedDict)
          case let nestedArray as [AnyCodable]:
              try container.encode(nestedArray)
          case is NSNull:
              try container.encodeNil()
          default:
              throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
          }
      }
  }

  struct CommsMessage: Codable {
    let data: AnyCodable
    let message: String
    let id: Int
  }
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
    guard let json = try? JSONDecoder().decode(CommsMessage.self, from: messageData) else {
      return .failure(CommsError(message: "Could not parse JSON '\(message)'"))
    }
    guard let callback = callbacks[json.message] else {
      return .failure(CommsError(message: "Missing callback '\(json.message)'"))
    }
    return .success((json.id, callback(json.data.value)))
  }
}
