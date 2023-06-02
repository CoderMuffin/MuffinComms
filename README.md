# MuffinComms
Message system for webkit

## In Swift
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
      guard let bundleUrl = Bundle.main.url(forResource: url, withExtension: "", subdirectory: "site") else {
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
## In JS
```js
await MuffinComms.send("ping", "pong")
```
