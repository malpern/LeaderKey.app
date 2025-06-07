import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group] = []

  var currentGroup: Group? {
    return navigationPath.last
  }

  init(
    userConfig: UserConfig!,
    lastChar: String? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.isShowingRefreshState = isShowingRefreshState
    navigationPath = []
  }

  func clear() {
    display = nil
    navigationPath = []
    isShowingRefreshState = false
  }

  func navigateToGroup(_ group: Group) {
    navigationPath.append(group)
  }
}
