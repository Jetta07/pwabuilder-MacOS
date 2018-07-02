//
//  ViewController.swift
//  MacOSpwa
//
//  Created by Rumsha Siddiqui on 6/7/18.
//  Copyright © 2018 Microsoft. All rights reserved.
//

import Cocoa
import WebKit

class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    
    // MARK: - App Properties
    var appName: String = ""
    var appStartUrl: String = ""
    var appURL: String = ""
    var appDisplay: String = ""
    var appThemeColor: String = ""
    var appScope: String = ""
    
    // MARK: - Local Properties
    var webView: WKWebView!
    var newWindowController: NSWindowController = NSWindowController()
    var newWebView: WKWebView!
    let backButton = NSButton()
    
    
    // MARK: - CUSTOM FUNCTIONS
    
    /*
     Navigates to the previous webpage when the back button is pressed
     */
    @objc func backButtonPressed(){
        if self.webView.canGoBack {
            self.webView.goBack()
        }
    }
    
    
    /*
     Displays the application in fullscreen mode
     */
    func fullscreen(){
        //TODO: look into fixing window screen size when exiting full screen mode (works for original ViewController code)
        view.window?.toggleFullScreen(self) //Enter full-screen mode
    }
    
    
    /*
     Displays the application in minimal-UI mode
     */
    func minimalUI(){ //Has a back button
        //TODO: Back button design style
        backButton.title = "BACK"
        backButton.isBordered = false
        
        //TODO: Fix back button alignment
        let titleBarView = view.window!.standardWindowButton(.closeButton)!.superview!
        titleBarView.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleBarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[backButton]-2-|", options: [], metrics: nil, views: ["backButton": backButton])) //places back button on right
        titleBarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-3-[backButton]-3-|", options: [], metrics: nil, views: ["backButton": backButton]))
        
        backButton.action = #selector(ViewController.backButtonPressed)
    }
    
    
    
    // MARK: - OVERRIDE FUNCTIONS
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        //TODO: Test scope feature
        let newUrlString = (navigationAction.request.url?.absoluteString)!
        
        if ManifestParser.isUrlInManifestScope(urlString: newUrlString, startUrlString: appStartUrl, scopeString: appScope) {
            //Within scope: Open new app window
            newWindowController = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "mainWindow")) as! NSWindowController
            let vc = newWindowController.contentViewController as! ViewController
            vc.appURL = newUrlString
            newWindowController.contentViewController?.viewDidLoad()
            newWindowController.showWindow(self)
            
        } else{
            //Out of scope: Open new window in Safari
            NSWorkspace.shared.open(URL(string: newUrlString)!)
        }
        return nil
    }
    
    /*
     Called when a JS message is sent to the handler. Receives and prints the JS message
     */
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        NSLog("FromJSConsole: %@", message.body as! NSObject)
    }
    
    
    override func loadView() {
        //TODO: Remove this later --- PWABuilder will load data from manifest
        //Load data from manifest
         let path = Bundle.main.path(forResource: "PWAinfo/manifest", ofType: "json")
         let url = URL(fileURLWithPath: path!)
         do {
            let jsonData = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String:Any]
            ManifestParser.parseManifest(json: json)
            appName = ManifestParser.getAppName()
            appStartUrl = ManifestParser.getAppURL()
            appURL = ManifestParser.getAppURL()
            appDisplay = ManifestParser.getAppDisplay()
            appThemeColor = ManifestParser.getAppThemeColor()
            appScope = ManifestParser.getAppScope()
         } catch {
            print(error)
         }
        
        //Inject JS string to read console.logs
        let configuration = WKWebViewConfiguration()
        let action = "var originalCL = console.log; console.log = function(msg){ originalCL(msg); window.webkit.messageHandlers.iosListener.postMessage(msg); }" //Run original console.log function + print it in Xcode console
        let script = WKUserScript(source: action, injectionTime: .atDocumentStart, forMainFrameOnly: false) //Inject script at the start of the document
        configuration.userContentController.addUserScript(script)
        configuration.userContentController.add(self, name: "iosListener")
        
        //Initialize WKWebView
        webView = WKWebView(frame: (NSScreen.main?.frame)!, configuration: configuration)
        
        //Set delegates and load view in the window
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //TODO: Find Safari version automatically
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/602.3.12 (KHTML, like Gecko) Version/10.0.2 Safari/602.3.12"
        
        //Load URL
        if let url = URL(string: appURL){
            let request = URLRequest(url: url as URL)
            webView.load(request)
            webView.allowsBackForwardNavigationGestures = true //allow backward and forward navigation by swiping
        }
    }
    
    override func viewDidAppear() {
        view.window?.title = appName
        view.window?.backgroundColor = NSColor.convertHexToNSColor(hexString: appThemeColor)//set title bar to a custom color
        
        //Display properties: standalone mode is the default
        if ManifestParser.isFullscreen(display: appDisplay) {
            fullscreen()
        } else if ManifestParser.isMinimalUI(display: appDisplay) {
            minimalUI()
        }
    }
    
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
