import Cocoa
import Combine
import Defaults
import SwiftUI

enum KeyHelpers: UInt16 {
  case Return = 36
  case Tab = 48
  case Space = 49
  case Backspace = 51
  case Escape = 53
}

class Controller {
  var userState: UserState
  var userConfig: UserConfig

  var window: Window!
  var cheatsheetWindow: NSWindow!

  init(userState: UserState, userConfig: UserConfig) {
    self.userState = userState
    self.userConfig = userConfig
    self.cheatsheetWindow = Cheatsheet.createWindow(for: userState)
  }

  func show() {
    window.show()
    if Defaults[.alwaysShowCheatsheet] {
      showCheatsheet()
    }
  }

  func hide(afterClose: (() -> Void)? = nil) {
    window.hide {
      self.clear()
      afterClose?()
    }
    cheatsheetWindow?.orderOut(nil)
  }

  func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      switch event.charactersIgnoringModifiers {
      case ",":
        NSApp.sendAction(
          #selector(AppDelegate.settingsMenuItemActionHandler(_:)), to: nil,
          from: nil)
        hide()
        return
      case "w":
        hide()
        return
      case "q":
        NSApp.terminate(nil)
        return
      default:
        break
      }
    }

    switch event.keyCode {
    case KeyHelpers.Backspace.rawValue:
      clear()
    case KeyHelpers.Escape.rawValue:
      hide()
    default:
      let keyCode = event.keyCode
      var char: String =
        (Defaults[.forceEnglishKeyboardLayout]
          ? ENGLISH_KEYMAP[keyCode]
          : event.charactersIgnoringModifiers) ?? ""

      // Check if Shift is pressed and convert to uppercase if so
      if event.modifierFlags.contains(.shift) {
        char = char.uppercased()
      }

      if char == "?" {
        showCheatsheet()
        return
      }

      let list =
        (userState.currentGroup != nil)
        ? userState.currentGroup : userConfig.root

      let hit = list?.actions.first { item in
        switch item {
        case let .group(group):
          if group.key == char {
            return true
          }
        case let .action(action):
          if action.key == char {
            return true
          }
        }
        return false
      }

      switch hit {
      case let .action(action):
        hide {
          self.runAction(action)
        }
      case let .group(group):
        userState.display = group.key
        userState.currentGroup = group
      case .none:
        window.shake()
      }
    }

    // Why do we need to wait here?
    delay(1) {
      self.positionCheatsheetWindow()
    }
  }

  private func positionCheatsheetWindow() {
    guard let mainWindow = window, let cheatsheet = cheatsheetWindow else {
      return
    }
    let frame = mainWindow.frame
    let point = NSPoint(
      x: frame.maxX + 20,
      y: frame.midY - cheatsheet.frame.height / 2
    )
    cheatsheet.setFrameOrigin(point)
  }

  private func showCheatsheet() {
    positionCheatsheetWindow()
    cheatsheetWindow?.orderFront(nil)
  }

  private func runAction(_ action: Action) {
    switch action.type {
    case .application:
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: action.value),
        configuration: NSWorkspace.OpenConfiguration())
    case .url:
      openURL(action)
    case .command:
      CommandRunner.run(action.value)
    case .folder:
      NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: action.value)
    default:
      print("\(action.type) unknown")
    }
  }

  private func clear() {
    userState.clear()
  }

  private func openURL(_ action: Action) {
    guard let url = URL(string: action.value) else {
      showAlert(title: "Invalid URL", message: "Failed to parse URL: \(action.value)")
      return
    }

    guard let scheme = url.scheme else {
      showAlert(
        title: "Invalid URL",
        message: "URL is missing protocol (e.g. https://, raycast://): \(action.value)")
      return
    }

    if scheme == "http" || scheme == "https" {
      NSWorkspace.shared.open(
        url,
        configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(
        url,
        configuration: DontActivateConfiguration.shared.configuration)
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}
