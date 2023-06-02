# MuffinComms
Asynchronous wrapper around the message system for WKWebView

## Why?
Making vanilla web apps that use local files is difficult in iOS. XHR requests suddenly become more difficult to use, resulting in CORS errors, and permissions will often need confirmation twice - once for the app, and once for the web view. If you own both the web view and the local files, why is this so difficult? This is the problem that MuffinComms addresses.

## Get Started
Include comms.js in your HTML file and add MuffinComms.swift to your iOS project. Then, initialize MuffinComms like so:
```swift
let cfg = WKWebViewConfiguration()
let ucc = WKUserContentController()

let mc = MuffinComms(contentController: ucc)
// add callbacks
// configure `cfg` and `ucc`

cfg.userContentController = ucc
webView = WKWebView(frame: .zero, configuration: cfg)
mc.webView = webView
```
No initialization is needed for the JS side. You are now ready to start registering handlers and receiving requests. Here is an example that retrieves the content of a file bundled with the app from JS
```swift
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
```
```js
let fileContent = await MuffinComms.send("file", "sounds/honk.mp3", "arraybuffer"); // -> an arraybuffer containing the content of sounds/honk.mp3
```
Note that no data is needed, so the following is perfectly fine:
```swift
mc.addCallback("location") { _ in 
  //return device location here
}
```
```js
let location = await MuffinComms.send("location");
```
## Full example
Swift app hosting WKWebView
```swift
let cfg = WKWebViewConfiguration()
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

## Troubleshooting
+ Check console - MuffinComms should print to the js console and the swift console if any of these errors occur
+ Make sure `MuffinComms.webView` is assigned to the target webview
+ Make sure that the `userContentController` is attached to the `webViewConfiguration`, and make sure that the configuratoin is attached to the `WebView`
+ Make sure there are no duplicate event handlers
+ Make sure that all of the methods and classes are called and created in the correct order (see full example)

# Docs
## JS
## isAvailabile
```js
function MuffinComms.isAvailable() -> boolean
```
Returns true or false depending on whether the `muffinComms` webkit message handler was found. NOTE: MuffinComms may produce unexpected results if your project also uses the `muffinComms` wekbit message handler.

## send
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
## CommsCallback
```swift
typealias MuffinComms.CommsCallback = (Any) -> CommsResult
```
Typealias representing the type of a callback invoked by `addCallback`

## CommsResult
```swift
enum MuffinComms.CommsResult {
  case .ok(_: Data)
  case .error(_: String)
}
```
Enumeration with the possible results of a `CommsCallback`. If the operation completed successfully, the data passed is base64 encoded and sent to `comms.js`

## addCallback
```swift
func MuffinComms.addCallback(message: String, callback: @escaping CommsCallback) -> Void
```
Registers a callback handler for the given message. When `MuffinComms.send(message, data)` is called on the web page, the callback that has the same message is called with this data.
The data is parsed into JSON before it is passed to the callback, allowing the callback to make conversions such as `as String`, `as Int`, `as Bool`, `as Double`, `as [T]`, and `as [String: T]` (for any T).

