# MuffinComms
Asynchronous message system for WKWebView

## JS
## `MuffinComms.isAvailabile`
```js
function MuffinComms.isAvailable() -> boolean
```
Returns true or false depending on whether the `muffinComms` webkit message handler was found. NOTE: MuffinComms may produce unexpected results if your project also uses the `muffinComms` wekbit message handler.

## `MuffinComms.send`
```js
function MuffinComms.send(message: string, data: any, responseType: String = "text") -> Promise
```
Sends a request to the swift backend, and returns a promise that resolves when the swift backend returns a result.
| `responseType` | Promise type |
|----------------|--------------|
| `"text"`       | `Promise<string>` |
| `"json"`       | `Promise<any>` |
| `"arraybuffer"` | `Promise<ArrayBuffer>` |


## Swift
## `MuffinComms.CommsCallback`
```swift
typealias MuffinComms.CommsCallback = (Any) -> CommsResult
```
Typealias representing the type of a callback invoked by `addCallback`

## `MuffinComms.CommsResult`
```swift
enum MuffinComms.CommsResult {
  case .ok(_: Data)
  case .error(_: String)
}
```
Enumeration with the possible results of a `CommsCallback`. If the operation completed successfully, the data passed is base64 encoded and sent to `comms.js`
---
## `MuffinComms.addCallback`
```swift
func MuffinComms.addCallback(message: String, callback: @escaping CommsCallback) -> Void
```
Registers a callback handler for the given message. When `MuffinComms.send(message, data)` is called on the web page, the callback that has the same message is called with this data.
The data is parsed into JSON before it is passed to the callback, allowing the callback to make conversions such as `as String`, `as Int`, `as Bool`, `as Double`, `as [T]`, and `as [String: T]` (for any T).


## Sample Usage
Swift app hosting WKWebView
```swift
let cfg = WKWebViewConfiguration()
cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
let ucc = WKUserContentController()

let mc = MuffinComms(contentController: ucc)

mc.addCallback("ping") { data in
  return .ok((data as! String + "!").data(using: .utf8)!)
}

mc.addCallback("file") { url in
  guard let url = url as? String else {
    return .error("Expected URL to be a string")
  }
  guard let bundleUrl = Bundle.main.url(forResource: url, withExtension: "", subdirectory: "site")
  else {
    return .error("Could not resolve bundle URL '\(url)'")
  }
  do {
    return .ok(try Data(contentsOf: bundleUrl))
  } catch {
    return .error("Could not get contents for bundle URL '\(url)'")
  }
}

cfg.userContentController = ucc
wv = WKWebView(frame: .zero, configuration: cfg)
mc.webView = wv
```
JS on the webview:
```js
await MuffinComms.send("ping", "pong") // -> "pong!"
await MuffinComms.send("file", "sounds/honk.mp3", "arraybuffer") // -> contents of `sounds/honk.mp3` as an ArrayBuffer
```
