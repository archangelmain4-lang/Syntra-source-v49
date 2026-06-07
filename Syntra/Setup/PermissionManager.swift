//
//  PermissionManager.swift
//  Syntra
//
//  Created by occlusion on 5/4/25.
//

import Cocoa


class PermissionModel: ObservableObject {

    var isRequiredToShowPermission:Bool{
        return isRequiredToGrant
    }

    var isRequiredToGrant:Bool{
        let result = !screenCapturePermission || !accessibilityPermission
        return result
    }
    @Published var screenCapturePermission = false
    @Published var screenCaptureRequireRestart = false
    @Published var accessibilityPermission = false
    @Published var userRequestedAccessibility = false
    @Published var userRequestedScreenCapture = false
}

class PermissionManager: NSObject{
    
    @objc static let shared = PermissionManager()
    
    let model = PermissionModel()
    
    @objc var isRequiredToShow:Bool{
        let result = !screenCapturePermission || !accessibilityPermission
        return result
    }
    
    @objc var screenCapturePermission:Bool{
        // CoreGraphics screen capture works on macOS 12.5+, but still requires
        // Screen Recording permission for automatic on-screen context.
        return CGPreflightScreenCaptureAccess() || UserDefaults.standard.bool(forKey: "ManualScreenCaptureGranted")
    }

    /// The app targets macOS 12.5+, and the current capture pipeline supports it.
    @objc static var isScreenCaptureSupported: Bool {
        return true
    }
    
    @objc var accessibilityPermission:Bool{
        return AXIsProcessTrusted() || UserDefaults.standard.bool(forKey: "ManualAccessibilityGranted")
    }
    
    var checkTimer: Timer?
    var lastStatus = false
    var didFinish:(()->Void)? = nil

    
    override init() {
        
        super.init()
        
        self.lastStatus = self.isRequiredToShow

        checkTimer?.invalidate()
        checkTimer = Timer(timeInterval: 1.0, repeats: true, block: { timer in
            self.checkPermission()
        })
        
        self.checkPermission()

        RunLoop.main.add(checkTimer!, forMode: .common)


    }
    
    func checkPermission() {
        self.model.screenCapturePermission = self.screenCapturePermission
        self.model.accessibilityPermission = self.accessibilityPermission

        // Use the helper probe when bundled; otherwise fall back to preflight/manual state.
        if PermissionManager.isScreenCaptureSupported,
           let cliURL = Bundle.main.url(forResource: "ScreenCapturePermissionHelper", withExtension: nil, subdirectory: ""){
            let proc = Process()
            proc.executableURL = cliURL
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let permission = str == "1"
            if permission {
                if self.model.screenCapturePermission == false {
                    self.model.screenCaptureRequireRestart = true
                } else {
                    self.model.screenCapturePermission = true
                    self.model.screenCaptureRequireRestart = false
                }
            }
            else{
                self.model.screenCaptureRequireRestart = false
            }
        } else {
            // Helper binary unavailable (older macOS bundles). Fallback: if the user
            // already clicked "Grant Access" and the in-process preflight still
            // reports false, assume a restart is needed so we never get stuck.
            if self.model.userRequestedScreenCapture && !self.model.screenCapturePermission {
                self.model.screenCaptureRequireRestart = true
            }
        }
        
        let effectiveScreenCaptureGranted = self.model.screenCapturePermission || (!self.model.screenCaptureRequireRestart && self.screenCapturePermission)
        let effectiveRequiredToShow = !effectiveScreenCaptureGranted || !self.model.accessibilityPermission

        if self.lastStatus != effectiveRequiredToShow{
            self.lastStatus = effectiveRequiredToShow
            if !effectiveRequiredToShow{
                self.didFinish?()
                self.didFinish = nil
                checkTimer?.invalidate()
                checkTimer = nil
            }
        }

        // Keep global shortcuts armed and attach the Accessibility event-tap
        // fallback as soon as permission is granted, without prompting again.
        InputEventManager.shared.setup()
    }
    
        
    func requestScreenCapturePermission() {
        guard !screenCapturePermission else{return}
        DispatchQueue.main.async { self.model.userRequestedScreenCapture = true }
        if !CGRequestScreenCaptureAccess(){
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0, execute: {
                let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                if let aString = URL(string: urlString) {
                    NSWorkspace.shared.open(aString)
                }
            })
        }
        
    }

    func trustScreenCapturePermissionForSetup() {
        UserDefaults.standard.set(true, forKey: "ManualScreenCaptureGranted")
        DispatchQueue.main.async {
            self.model.screenCapturePermission = true
            self.model.screenCaptureRequireRestart = false
            self.checkPermission()
        }
    }
    
    func requestAccessibilityPermission() {
        guard !accessibilityPermission else{return}
        DispatchQueue.main.async { self.model.userRequestedAccessibility = true }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        if !AXIsProcessTrustedWithOptions(options){
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0, execute: {
                let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                if let aString = URL(string: urlString) {
                    NSWorkspace.shared.open(aString)
                }
            })
        }
    }

    func trustAccessibilityPermissionForSetup() {
        UserDefaults.standard.set(true, forKey: "ManualAccessibilityGranted")
        DispatchQueue.main.async {
            self.model.accessibilityPermission = true
            self.checkPermission()
        }
    }

    func refreshPermissions() {
        DispatchQueue.main.async {
            self.checkPermission()
        }
    }
    
    func restartApp() {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(3.0); open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        
        NSApp.terminate(self)
    }
    
    
}
