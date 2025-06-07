import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  @State private var contentWidth = 540.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @State private var expandedGroups: Set<[Int]> = []

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(title: "Shortcut") {
        KeyboardShortcuts.Recorder(for: .activate)
      }

      Settings.Section(title: "App") {
        LaunchAtLogin.Toggle()
      }

      Settings.Section(title: "Config", bottomDivider: true, verticalAlignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          VStack {
            ConfigEditorSheetView(group: $config.root, expandedGroups: $expandedGroups)
              .frame(height: 500)
              // Probably horrible for accessibility but improves performance a ton
              .focusable(false)
          }
          .padding(8)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .inset(by: 1)
              .stroke(Color.primary, lineWidth: 1)
              .opacity(0.1)
          )

          HStack {
            // Left-aligned buttons
            HStack(spacing: 8) {
              Button("Save to file") {
                config.saveConfig()
              }

              Button("Reload from file") {
                config.reloadConfig()
              }
            }

            Spacer()

            // Right-aligned buttons
            HStack(spacing: 8) {
              Button(action: {
                withAnimation(.easeOut(duration: 0.1)) {
                  expandAllGroups(in: config.root, parentPath: [])
                }
              }) {
                Image(systemName: "chevron.down")
                Text("Expand all")
              }

              Button(action: {
                withAnimation(.easeOut(duration: 0.1)) {
                  expandedGroups.removeAll()
                }
              }) {
                Image(systemName: "chevron.right")
                Text("Collapse all")
              }
            }
          }
        }
      }
    }
  }

  private func expandAllGroups(in group: Group, parentPath: [Int]) {
    for (index, item) in group.actions.enumerated() {
      let currentPath = parentPath + [index]
      if case .group(let subgroup) = item {
        expandedGroups.insert(currentPath)
        expandAllGroups(in: subgroup, parentPath: currentPath)
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
