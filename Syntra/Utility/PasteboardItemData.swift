//
//  PasteboardItemData.swift
//  Syntra
//
//  Created by occlusion on 6/2/25.
//

import Cocoa

/// Represents a single pasteboard item with all its types and raw Data.
public struct PasteboardItemData {
    /// English comment only:
    /// Array of pasteboard UTI types (e.g. ["public.utf8-plain-text", "public.tiff", ...]).
    public let types: [NSPasteboard.PasteboardType]
    /// English comment only:
    /// Parallel array holding the raw Data for each corresponding type in `types`.
    public let dataForTypes: [Data]

    /// English comment only:
    /// Initializer that captures types and data snapshot from a given NSPasteboardItem.
    public init(item: NSPasteboardItem) {
        self.types = item.types
        var dataList: [Data] = []
        for type in self.types {
            if let data = item.data(forType: type) {
                dataList.append(data)
            } else {
                dataList.append(Data())
            }
        }
        self.dataForTypes = dataList
    }

    /// English comment only:
    /// Reconstructs an NSPasteboardItem from this snapshot.
    public func toPasteboardItem() -> NSPasteboardItem {
        let newItem = NSPasteboardItem()
        for (index, type) in self.types.enumerated() {
            let data = self.dataForTypes[index]
            if !data.isEmpty {
                newItem.setData(data, forType: type)
            }
        }
        return newItem
    }
    
    
    
}

public extension NSPasteboard {
    /// English comment only:
    /// Creates a deep snapshot of the entire pasteboard contents (all items and all types).
    /// - Returns: Array of `PasteboardItemData` capturing every item and type in the pasteboard.
    func backupAllItems() -> [PasteboardItemData] {
        guard let items = self.pasteboardItems, !items.isEmpty else {
            return []
        }
        var backup: [PasteboardItemData] = []
        for item in items {
            let itemData = PasteboardItemData(item: item)
            backup.append(itemData)
        }
        return backup
    }
    
    /// English comment only:
    /// Clears the pasteboard and restores it from the provided snapshot.
    /// - Parameter backup: Array of `PasteboardItemData` to be restored.
    func restoreAllItems(from backup: [PasteboardItemData]) {
        // English comment only:
        // First, clear the current contents.
        self.clearContents()
        // English comment only:
        // Reconstruct each NSPasteboardItem and write them back.
        let newItems = backup.map { $0.toPasteboardItem() }
        self.writeObjects(newItems)
    }
    
    static var inFlightTask: Task<String?, Never>?
    
    static func getSelectedText(wid: CGWindowID) async -> String? {
      if let task = inFlightTask {
        return await task.value
      }

      // 新しい Task を生成して inFlightTask にセット
      let task = Task<String?, Never> {
          return await NSPasteboard.general.getSelectedText(wid: wid)
      }
      inFlightTask = task

      defer { inFlightTask = nil }

      return await task.value
    }

    func getSelectedText(wid: CGWindowID) async -> String? {
        let pasteboard = NSPasteboard.general
        let existingItems = pasteboard.backupAllItems()
        pasteboard.clearContents()
        pasteboard.setString("", forType: .string)
        
        sendCommandC(to: wid)
        try? await Task.sleep(nanoseconds: 180_000_000)
        let copiedString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 5) Restore original pasteboard if needed
        NSPasteboard.general.clearContents()
        NSPasteboard.general.restoreAllItems(from: existingItems)
        return copiedString
    }
    
    
    
    /// Sends a Command+C keypress to the application owning the given window ID.
    /// - Parameter targetWindowID: The CGWindowID of the window you want to target.
    func sendCommandC(to targetWindowID: CGWindowID) {
        // 1) Get the PID of the process that owns targetWindowID
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionIncludingWindow], targetWindowID) as? [[String: Any]],
              let firstInfo = windowInfoList.first,
              let pid = firstInfo[kCGWindowOwnerPID as String] as? pid_t else {
            print("Failed to obtain PID for window \(targetWindowID)")
            return
        }

        for w in listMenuForWindow(windowID: targetWindowID, title: "Edit"){
            if w.shortcutChar?.lowercased() == "c"{
                if !w.isEnabled{
                    return
                }
            }
        }
        // 2) Activate the app with that PID (bring its windows to front)
        if let app = NSRunningApplication(processIdentifier: pid) {
            // Activate ignoring other apps so the window actually becomes frontmost
            app.activate(options: [.activateIgnoringOtherApps])
        } else {
            print("No running application for PID \(pid)")
            return
        }

        // 3) Briefly wait to ensure the window is frontmost before sending keys
        //    This small delay can be tuned if necessary.
//        usleep(10_000)

        // 4) Create and post Command (⌘) + C key-down, then key-up events
        let cmdFlag: CGEventFlags = .maskCommand
        let keyCCode: CGKeyCode = 8  // Virtual keycode for 'C' on a US keyboard

        // Create a key-down event for 'C' with ⌘ held
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCCode, keyDown: true) {
            keyDown.flags = cmdFlag
            keyDown.post(tap: .cghidEventTap)
        }

        // Create a key-up event for 'C' with ⌘ held
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCCode, keyDown: false) {
            keyUp.flags = cmdFlag
            keyUp.post(tap: .cghidEventTap)
        }
    }

    

    
    /// Represents a single menu item with title, role, shortcut information, and enabled state.
    public struct MenuItemInfo {
        /// English comment only:
        /// The title of the menu item (e.g. "Copy", "Paste", "File", etc.).
        public let title: String
        /// English comment only:
        /// The accessibility role of this element (e.g. kAXMenuItemRole, kAXMenuRole, kAXMenuBarItemRole).
        public let role: String
        /// English comment only:
        /// If this item has a keyboard shortcut, this contains the character (e.g. "C", "V").
        public let shortcutChar: String?
        /// English comment only:
        /// If this item has a keyboard shortcut, this contains the modifier flags (e.g. command, shift).
        public let shortcutModifiers: Int?
        /// English comment only:
        /// Full hierarchical path of this menu item, e.g. ["Edit", "Copy"] or ["File", "New", "Project"].
        public let path: [String]
        /// English comment only:
        /// Indicates whether this menu item is currently enabled (i.e. can be selected).
        public let isEnabled: Bool
    }

    /// Recursively traverses a given AXUIElement (which is assumed to be a menu or a menu bar item)
    /// and collects all MenuItemInfo under it, including enabled state.
    private func collectMenuItems(
        from element: AXUIElement,
        parentPath: [String] = []
    ) -> [MenuItemInfo] {
        var results: [MenuItemInfo] = []
        
        var roleValue: CFTypeRef?

        // 3) Check enabled state for this element (if applicable)
        var enabledState: Bool = true
        let enabledErr = AXUIElementCopyAttributeValue(
            element,
            kAXEnabledAttribute as CFString,
            &roleValue
        )
        if enabledErr == .success, let isEnabled = roleValue as? Bool {
            enabledState = isEnabled
        }
        // 1) Get this element's title (if available)
        var titleValue: CFTypeRef?
        let titleErr = AXUIElementCopyAttributeValue(
            element,
            kAXTitleAttribute as CFString,
            &titleValue
        )
        var currentTitle: String = ""
        if titleErr == .success, let t = titleValue as? String {
            currentTitle = t
        }
        
        // 2) Get this element's role
        let roleErr = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )
        let roleString: String = {
            if roleErr == .success, let r = roleValue as? String {
                return r
            } else {
                return ""
            }
        }()
        
        
        // 4) Read shortcut character and modifiers if this is a menu item
        var shortcutChar: String? = nil
        var shortcutMod: Int? = nil
        if roleString == kAXMenuItemRole as String {
            // Read the character used for shortcut (e.g. "C")
            var charValue: CFTypeRef?
            let charErr = AXUIElementCopyAttributeValue(
                element,
                kAXMenuItemCmdCharAttribute as CFString,
                &charValue
            )
            if charErr == .success, let c = charValue as? String {
                shortcutChar = c
            }
            // Read the modifier mask for that shortcut
            var modValue: CFTypeRef?
            let modErr = AXUIElementCopyAttributeValue(
                element,
                kAXMenuItemCmdModifiersAttribute as CFString,
                &modValue
            )
            if modErr == .success, let m = modValue as? Int {
                shortcutMod = m
            }
            
            // Create a MenuItemInfo for this menu item
            let itemInfo = MenuItemInfo(
                title: currentTitle,
                role: roleString,
                shortcutChar: shortcutChar,
                shortcutModifiers: shortcutMod,
                path: parentPath + [currentTitle],
                isEnabled: enabledState
            )
            results.append(itemInfo)
        }
        
        // 5) Even if it's a menu item, it might have a submenu (role == kAXMenuRole or kAXMenuBarItemRole can have children)
        //    So attempt to get its children and recurse.
        var childrenValue: CFTypeRef?
        let childrenErr = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        )
        if childrenErr == .success, let children = childrenValue as? [AXUIElement] {
            // If this element has children, recurse into each child
            for child in children {
                let nextPath = currentTitle.isEmpty ? parentPath : (parentPath + [currentTitle])
                results.append(contentsOf: collectMenuItems(from: child, parentPath: nextPath))
            }
        }
        
        return results
    }

    /// Enumerates all menu items for the application owning the given window ID.
    /// Returns an array of MenuItemInfo representing the entire menu hierarchy,
    /// including each item's enabled state and shortcut info.
    /// - Parameter windowID: CGWindowID of the target window.
    /// - Returns: Array of MenuItemInfo for every menu item in that app, or empty if unavailable.
    public func listMenuForWindow(windowID: CGWindowID, title:String? = nil) -> [MenuItemInfo] {
        // 1) Determine PID from window ID
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let firstInfo = windowInfoList.first,
              let pid = firstInfo[kCGWindowOwnerPID as String] as? pid_t else {
            return []
        }
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        usleep(10000)

        // 2) Create an AXUIElement for the application
        let axApp: AXUIElement = AXUIElementCreateApplication(pid)
        
        // 3) Access its menu bar
        var menuBarCF: CFTypeRef?
        let menuBarErr = AXUIElementCopyAttributeValue(
            axApp,
            kAXMenuBarAttribute as CFString,
            &menuBarCF
        )
        guard menuBarErr == .success, let menuBar = menuBarCF as! AXUIElement? else {
            return []
        }
        
        // 4) Get the top-level menu bar items (File, Edit, View, etc.)
        var menuBarChildrenCF: CFTypeRef?
        let childrenErr = AXUIElementCopyAttributeValue(
            menuBar,
            kAXChildrenAttribute as CFString,
            &menuBarChildrenCF
        )
        guard childrenErr == .success, let menuBarItems = menuBarChildrenCF as! [AXUIElement]? else {
            return []
        }
        
        // 5) For each top-level menu bar item, recurse into its hierarchy
        var allMenuItems: [MenuItemInfo] = []
        for topItem in menuBarItems {
            // 1) Get this element's title (if available)
            var titleValue: CFTypeRef?
            let titleErr = AXUIElementCopyAttributeValue(
                topItem,
                kAXTitleAttribute as CFString,
                &titleValue
            )
            var currentTitle: String = ""
            if titleErr == .success, let t = titleValue as? String {
                currentTitle = t
            }
            if let title = title{
                if currentTitle != title{
                    continue
                }
            }
            allMenuItems.append(contentsOf: collectMenuItems(from: topItem, parentPath: []))
        }
        
        return allMenuItems
    }

}
