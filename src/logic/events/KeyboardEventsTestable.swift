import ShortcutRecorder

class KeyboardEventsTestable {
    static let globalShortcutsIds = [
        "nextWindowShortcut": 0,
        "nextWindowShortcut2": 1,
        "nextWindowShortcut3": 2,
        "holdShortcut": 5,
        "holdShortcut2": 6,
        "holdShortcut3": 7,
    ]
    
    // Map of macOS virtual key codes to characters (normal, shifted)
    // Note: Some keyCodes are intentionally omitted (e.g., 10 is unmapped, 36 is Return)
    static let keyCodeMap: [UInt32: (String, String)] = [
        0: ("a", "A"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"), 4: ("h", "H"),
        5: ("g", "G"), 6: ("z", "Z"), 7: ("x", "X"), 8: ("c", "C"), 9: ("v", "V"),
        11: ("b", "B"), 12: ("q", "Q"), 13: ("w", "W"), 14: ("e", "E"), 15: ("r", "R"),
        16: ("y", "Y"), 17: ("t", "T"), 18: ("1", "!"), 19: ("2", "@"), 20: ("3", "#"),
        21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("=", "+"), 25: ("9", "("),
        26: ("7", "&"), 27: ("-", "_"), 28: ("8", "*"), 29: ("0", ")"), 30: ("]", "}"),
        31: ("o", "O"), 32: ("u", "U"), 33: ("[", "{"), 34: ("i", "I"), 35: ("p", "P"),
        37: ("l", "L"), 38: ("j", "J"), 39: ("'", "\""), 40: ("k", "K"), 41: (";", ":"),
        42: ("\\", "|"), 43: (",", "<"), 44: ("/", "?"), 45: ("n", "N"), 46: ("m", "M"),
        47: (".", ">"), 49: (" ", " ")
        // Note: keyCode 36 is Return/Enter (handled separately if needed)
        // Note: keyCode 48 is Tab (used for window switching)
        // Note: keyCode 51 is Delete/Backspace (handled separately)
        // Note: keyCode 53 is Escape (handled separately)
    ]
}

@discardableResult
func handleKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) -> Bool {
    Logger.debug(globalId, shortcutState, keyCode, modifiers, isARepeat, NSEvent.modifierFlags)
    
    // Handle search input when app is being used and appearance style is titles
    if App.app.appIsBeingUsed && Preferences.appearanceStyle == .titles && keyCode != nil {
        if handleSearchInput(keyCode!, modifiers) {
            return true
        }
    }
    
    var someShortcutTriggered = false
    for shortcut in ControlsTab.shortcuts.values {
        if shortcut.matches(globalId, shortcutState, keyCode, modifiers) && shortcut.shouldTrigger() {
            shortcut.executeAction(isARepeat)
            // we want to pass-through alt-up to the active app, since it saw alt-down previously
            if !shortcut.id.starts(with: "holdShortcut") {
                someShortcutTriggered = true
            }
        }
        shortcut.redundantSafetyMeasures()
    }
    // TODO if we manage to move all keyboard listening to the background thread, we'll have issues returning this boolean
    // this function uses many objects that are also used on the main-thread. It also executes the actions
    // we'll have to rework this whole approach. Today we rely on somewhat in-order events/actions
    // special attention should be given to App.app.appIsBeingUsed which is being set to true when executing the nextWindowShortcut action
    return someShortcutTriggered
}

private func handleSearchInput(_ keyCode: UInt32, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
    // Only handle input when no modifier keys (except shift for capitals) are pressed
    let hasModifiers = modifiers?.contains(.command) ?? false ||
                      modifiers?.contains(.control) ?? false ||
                      modifiers?.contains(.option) ?? false
    
    if hasModifiers {
        return false
    }
    
    // Handle backspace (delete key)
    if keyCode == 51 { // kVK_Delete
        if !App.app.searchQuery.isEmpty {
            App.app.updateSearchQuery(String(App.app.searchQuery.dropLast()))
            return true
        }
        return false
    }
    
    // Handle escape to clear search
    if keyCode == 53 { // kVK_Escape
        if !App.app.searchQuery.isEmpty {
            App.app.clearSearchQuery()
            return true
        }
        // If search is empty, let the normal cancel shortcut handle it
        return false
    }
    
    // Convert keyCode to character
    if let character = keyCodeToCharacter(keyCode, modifiers?.contains(.shift) ?? false) {
        App.app.updateSearchQuery(App.app.searchQuery + character)
        return true
    }
    
    return false
}

private func keyCodeToCharacter(_ keyCode: UInt32, _ shift: Bool) -> String? {
    if let (normal, shifted) = KeyboardEventsTestable.keyCodeMap[keyCode] {
        return shift ? shifted : normal
    }
    return nil
}
