import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @State private var expandedGroups: Set<[Int]> = []

  var body: some View {
    VStack(spacing: 0) {
      // Main content area with scroll view
      ScrollView {
        ConfigEditorSheetView(group: $config.root, expandedGroups: $expandedGroups)
          .padding(20)
          // Probably horrible for accessibility but improves performance a ton
          .focusable(false)
      }
      
      // Bottom button bar
      VStack(spacing: 0) {
        Divider()
        HStack {
          Text("Shortcut:")
            .foregroundColor(.secondary)
          KeyboardShortcuts.Recorder(for: .activate)
          
          Spacer()
          
          LaunchAtLogin.Toggle {
            Text("Launch at startup")
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
      }
    }
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    return GeneralPane()
      .environmentObject(UserConfig())
  }
}
