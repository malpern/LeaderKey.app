import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SymbolPicker

let generalPadding: CGFloat = 8
let expandButtonWidth: CGFloat = 24

struct ConfigEditorToolbar: NSViewRepresentable {
  let onSave: () -> Void
  let onReload: () -> Void
  let onExpandAll: () -> Void
  let onCollapseAll: () -> Void

  func makeNSView(context: Context) -> NSView {
    let containerView = NSView()
    containerView.wantsLayer = true

    let toolbar = NSSegmentedControl()
    toolbar.segmentStyle = .texturedRounded
    toolbar.trackingMode = .momentary
    toolbar.segmentCount = 4
    toolbar.controlSize = .large

    // Configure segments
    toolbar.setImage(NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Save"), forSegment: 0)
    toolbar.setLabel("Save to file", forSegment: 0)
    // toolbar.setToolTip("Save to file", forSegment: 0)

    toolbar.setImage(NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload"), forSegment: 1)
    toolbar.setLabel("Reload", forSegment: 1)
    //toolbar.setToolTip("Reload from file", forSegment: 1)

    toolbar.setImage(NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Expand All"), forSegment: 2)
    toolbar.setLabel("Expand all", forSegment: 2)
    //toolbar.setToolTip("Expand all", forSegment: 2)

    toolbar.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Collapse All"), forSegment: 3)
    toolbar.setLabel("Collapse all", forSegment: 3)
    //toolbar.setToolTip("Collapse all", forSegment: 3)

    toolbar.target = context.coordinator
    toolbar.action = #selector(Coordinator.segmentClicked(_:))

    // Add toolbar to container
    containerView.addSubview(toolbar)
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      toolbar.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      toolbar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      containerView.heightAnchor.constraint(equalToConstant: 32)
    ])

    return containerView
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    // No updates needed
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject {
    let parent: ConfigEditorToolbar

    init(_ parent: ConfigEditorToolbar) {
      self.parent = parent
    }

    @objc func segmentClicked(_ sender: NSSegmentedControl) {
      switch sender.selectedSegment {
      case 0:
        parent.onSave()
      case 1:
        parent.onReload()
      case 2:
        parent.onExpandAll()
      case 3:
        parent.onCollapseAll()
      default:
        break
      }
    }
  }
}

struct ItemPositionKey: PreferenceKey {
  static var defaultValue: CGPoint = .zero
  static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    value = nextValue()
  }
}

protocol DragValueProtocol {
  var translation: CGSize { get }
  var location: CGPoint { get }
}

extension DragGesture.Value: DragValueProtocol {}
extension MockDragGestureValue: DragValueProtocol {}

struct KeyEventHandler: NSViewRepresentable {
  @ObservedObject var dragState: DragState

  func makeNSView(context: Context) -> NSView {
    let view = KeyEventNSView()
    view.dragState = dragState
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? KeyEventNSView {
      view.dragState = dragState
    }
  }

  class KeyEventNSView: NSView {
    var dragState: DragState? {
      didSet {
        // Observe drag state changes
        if let dragState = dragState {
          dragState.$isDragging.sink { [weak self] isDragging in
            if isDragging {
              DispatchQueue.main.async {
                self?.window?.makeFirstResponder(self)
              }
            }
          }.store(in: &cancellables)
        }
      }
    }

    private var cancellables = Set<AnyCancellable>()

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
      guard let dragState = dragState, dragState.isDragging else {
        super.keyDown(with: event)
        return
      }

      // Check for ESC key (keyCode 53)
      if event.keyCode == 53 {
        // Cancel the drag operation
        DispatchQueue.main.async {
          dragState.cancelDrag()
        }
      } else {
        super.keyDown(with: event)
      }
    }
  }
}

struct KeyCapturingView: NSViewRepresentable {
  let onCommandUp: () -> Void
  let onCommandDown: () -> Void
  let onArrowUp: () -> Void
  let onArrowDown: () -> Void
  let onCommandRight: () -> Void
  let onCommandLeft: () -> Void

  func makeNSView(context: Context) -> KeyCapturingNSView {
    let view = KeyCapturingNSView()
    view.onCommandUp = onCommandUp
    view.onCommandDown = onCommandDown
    view.onArrowUp = onArrowUp
    view.onArrowDown = onArrowDown
    view.onCommandRight = onCommandRight
    view.onCommandLeft = onCommandLeft
    return view
  }

  func updateNSView(_ nsView: KeyCapturingNSView, context: Context) {
    nsView.onCommandUp = onCommandUp
    nsView.onCommandDown = onCommandDown
    nsView.onArrowUp = onArrowUp
    nsView.onArrowDown = onArrowDown
    nsView.onCommandRight = onCommandRight
    nsView.onCommandLeft = onCommandLeft
  }

  class KeyCapturingNSView: NSView {
    var onCommandUp: (() -> Void)?
    var onCommandDown: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onCommandRight: (() -> Void)?
    var onCommandLeft: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Monitor for key events globally
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        return self?.handleKeyEvent(event) ?? event
      }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
      let isCommandPressed = event.modifierFlags.contains(.command)

      if isCommandPressed {
        switch event.keyCode {
        case 126:  // Up arrow
          print("Command+Up detected")
          onCommandUp?()
          return nil  // Consume the event
        case 125:  // Down arrow
          print("Command+Down detected")
          onCommandDown?()
          return nil  // Consume the event
        case 124:  // Right arrow
          print("Command+Right detected")
          onCommandRight?()
          return nil  // Consume the event
        case 123:  // Left arrow
          print("Command+Left detected")
          onCommandLeft?()
          return nil  // Consume the event
        default:
          break
        }
      } else {
        // Handle plain arrow keys for navigation
        switch event.keyCode {
        case 126:  // Up arrow
          print("Up arrow detected")
          onArrowUp?()
          return nil  // Consume the event
        case 125:  // Down arrow
          print("Down arrow detected")
          onArrowDown?()
          return nil  // Consume the event
        default:
          break
        }
      }

      return event  // Let other events pass through
    }
  }
}

struct DragHandle: View {
  let onDragChanged: (any DragValueProtocol) -> Void
  let onDragEnded: (any DragValueProtocol) -> Void

  var body: some View {
    VStack(spacing: 2) {
      Rectangle()
        .fill(Color.secondary.opacity(0.6))
        .frame(width: 3, height: 2)
      Rectangle()
        .fill(Color.secondary.opacity(0.6))
        .frame(width: 3, height: 2)
      Rectangle()
        .fill(Color.secondary.opacity(0.6))
        .frame(width: 3, height: 2)
    }
    .frame(width: 12, height: 12)
    .background(
      DragHandleNSView(
        onDragChanged: onDragChanged,
        onDragEnded: onDragEnded
      )
    )
  }
}

struct DragHandleNSView: NSViewRepresentable {
  let onDragChanged: (any DragValueProtocol) -> Void
  let onDragEnded: (any DragValueProtocol) -> Void

  func makeNSView(context _: Context) -> NSView {
    let view = DragHandleView()
    view.onDragChanged = onDragChanged
    view.onDragEnded = onDragEnded
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    if let view = nsView as? DragHandleView {
      view.onDragChanged = onDragChanged
      view.onDragEnded = onDragEnded
    }
  }

  class DragHandleView: NSView {
    var onDragChanged: ((any DragValueProtocol) -> Void)?
    var onDragEnded: ((any DragValueProtocol) -> Void)?
    private var isDragging = false
    private var startPoint: CGPoint = .zero

    override func awakeFromNib() {
      super.awakeFromNib()
      setupTrackingArea()
    }

    override func viewDidMoveToSuperview() {
      super.viewDidMoveToSuperview()
      setupTrackingArea()
    }

    private func setupTrackingArea() {
      let trackingArea = NSTrackingArea(
        rect: bounds,
        options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
        owner: self,
        userInfo: nil
      )
      addTrackingArea(trackingArea)
    }

    override func mouseEntered(with _: NSEvent) {
      NSCursor.openHand.set()
    }

    override func mouseExited(with _: NSEvent) {
      if !isDragging {
        NSCursor.arrow.set()
      }
    }

    override func mouseDown(with event: NSEvent) {
      isDragging = true
      startPoint = convert(event.locationInWindow, from: nil)
      NSCursor.closedHand.set()

      // Trigger drag start immediately
      let dragValue = MockDragGestureValue(
        translation: .zero,
        location: startPoint
      )
      onDragChanged?(dragValue)
    }

    override func mouseDragged(with event: NSEvent) {
      let currentPoint = convert(event.locationInWindow, from: nil)
      let translation = CGPoint(
        x: currentPoint.x - startPoint.x,
        y: currentPoint.y - startPoint.y
      )

      // Create a mock DragGesture.Value
      let dragValue = MockDragGestureValue(
        translation: CGSize(width: translation.x, height: translation.y),
        location: currentPoint
      )

      onDragChanged?(dragValue)
    }

    override func mouseUp(with event: NSEvent) {
      isDragging = false
      let currentPoint = convert(event.locationInWindow, from: nil)
      let translation = CGPoint(
        x: currentPoint.x - startPoint.x,
        y: currentPoint.y - startPoint.y
      )

      // Create a mock DragGesture.Value
      let dragValue = MockDragGestureValue(
        translation: CGSize(width: translation.x, height: translation.y),
        location: currentPoint
      )

      onDragEnded?(dragValue)
      NSCursor.arrow.set()
    }
  }
}

struct MockDragGestureValue {
  let translation: CGSize
  let location: CGPoint
  let startLocation: CGPoint = .zero
  let time: Date = .init()
  let velocity: CGSize = .zero
  let predictedEndLocation: CGPoint = .zero
  let predictedEndTranslation: CGSize = .zero
}

struct AddButtons: View {
  let onAddAction: () -> Void
  let onAddGroup: () -> Void

  var body: some View {
    HStack(spacing: generalPadding) {
      Spacer().frame(width: 30)

      Button(action: onAddAction) {
        Image(systemName: "rays")
        Text("Add action")
      }
      Button(action: onAddGroup) {
        Image(systemName: "folder")
        Text("Add group")
      }
      Spacer()
    }
  }
}

class DragState: ObservableObject {
  @Published var draggedItem: ActionOrGroup?
  @Published var draggedFromPath: [Int]?
  @Published var currentDropTarget: DropTarget?  // Unified drop target
  @Published var isDragging: Bool = false
  @Published var dragLocation: CGPoint = .zero
  @Published var autoExpandTimer: Timer?
  @Published var hoveredGroupPath: [Int]?
  @Published var hoveredItemPath: [Int]?

  // Focus state for keyboard navigation
  @Published var focusedItemPath: [Int]?

  // Global handlers for cross-hierarchy operations
  var globalRemoveHandler: (([Int]) -> Void)?
  var globalInsertHandler: ((ActionOrGroup, [Int], Int) -> Void)?
  var globalMoveHandler: (([Int], [Int], Int) -> Void)?
  var updateDropTarget: ((CGPoint) -> Void)?

  func cancelDrag() {
    autoExpandTimer?.invalidate()
    autoExpandTimer = nil
    draggedItem = nil
    draggedFromPath = nil
    currentDropTarget = nil
    isDragging = false
    dragLocation = .zero
    NSCursor.arrow.set()
  }
}

// Represents a potential drop location
struct DropTarget: Equatable {
  let path: [Int]  // The path to the parent group
  let index: Int  // The index within the parent group
}

struct GroupContentView: View {
  @Binding var group: Group
  @EnvironmentObject var userConfig: UserConfig
  @EnvironmentObject var dragState: DragState
  var isRoot: Bool = false
  var parentPath: [Int] = []
  @Binding var expandedGroups: Set<[Int]>
  @Environment(\.rowFrames) private var rowFrames

  var body: some View {
    LazyVStack(spacing: 0) {  // Remove default spacing
      ForEach(group.actions.indices, id: \.self) { index in
        let currentPath = parentPath + [index]
        let item = group.actions[index]

        ConfigRowContainer(
          item: binding(for: index),
          index: index,
          currentPath: currentPath,
          isDragged: dragState.draggedFromPath == currentPath,
          group: $group,
          dragState: dragState,
          expandedGroups: $expandedGroups,
          parentPath: parentPath,
          performDrop: performDrop,
          startDrag: startDrag,
          handleGlobalDragMove: handleGlobalDragMove,
          endDrag: endDrag
        )
        .environmentObject(userConfig)

        // If the item is an expanded group, recursively render its contents
        if case .group = item, expandedGroups.contains(currentPath) {
          // Create a binding to the subgroup
          let subGroupBinding = Binding<Group>(
            get: {
              if index < self.group.actions.count, case .group(let g) = self.group.actions[index] {
                return g
              }
              return Group(key: "", actions: [])
            },
            set: { newSubGroup in
              if index < self.group.actions.count {
                self.group.actions[index] = .group(newSubGroup)
              }
            }
          )

          GroupContentView(
            group: subGroupBinding,
            isRoot: false,
            parentPath: currentPath,
            expandedGroups: $expandedGroups
          )
          .padding(.leading, 20)
        }
      }

      // Final drop zone at the end of a group
      if !group.actions.isEmpty {
        DropZoneView(
          isActive: dragState.currentDropTarget
            == DropTarget(
              path: parentPath, index: group.actions.count),
          performDrop: {
            performDrop(at: DropTarget(path: parentPath, index: group.actions.count))
          }
        )
        .frame(height: generalPadding)
      }

      AddButtons(
        onAddAction: {
          group.actions.append(
            .action(Action(key: "", type: .application, value: "")))
        },
        onAddGroup: {
          group.actions.append(.group(Group(key: "", actions: [])))
        }
      )
      .padding(.top, generalPadding * 0.5)
      .padding(.leading, 72)
    }
  }

  private func binding(for index: Int) -> Binding<ActionOrGroup> {
    Binding(
      get: { group.actions[index] },
      set: { group.actions[index] = $0 }
    )
  }

  private func startDrag(item: ActionOrGroup, fromPath: [Int]) {
    dragState.draggedItem = item
    dragState.draggedFromPath = fromPath
    dragState.isDragging = true
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }

  private func handleGlobalDragMove(value: DragGesture.Value) {
    dragState.dragLocation = value.location
    // Debounce to prevent jitter
    DispatchQueue.main.async {
      dragState.updateDropTarget?(value.location)
    }
  }

  private func endDrag() {
    if dragState.currentDropTarget != nil {
      performFinalDrop()
    }
    dragState.cancelDrag()
  }

  private func performFinalDrop() {
    // Safely unwrap all necessary properties and handlers for the drag operation.
    guard let draggedItem = dragState.draggedItem,
      let fromPath = dragState.draggedFromPath,
      let dropTarget = dragState.currentDropTarget,
      let globalRemoveHandler = dragState.globalRemoveHandler,
      let globalInsertHandler = dragState.globalInsertHandler
    else { return }

    // Create a new, independent reference to the item being moved.
    let itemToMove = draggedItem

    // 1. Remove the item from its original location first.
    globalRemoveHandler(fromPath)

    // 2. Adjust the drop target path based on the removal.
    // This is the critical step to ensure the destination is correct *after* the data has changed.
    var adjustedPath = dropTarget.path
    var adjustedIndex = dropTarget.index

    if fromPath.count == adjustedPath.count + 1 && fromPath.starts(with: adjustedPath) {
      // Moving item out of a group. No adjustment needed.
    } else if adjustedPath.starts(with: fromPath.dropLast()) && fromPath.last! < adjustedIndex {
      // Moving item to a later position in the same group.
      adjustedIndex -= 1
    } else if let (commonAncestor, fromBranch, toBranch) = findCommonAncestor(
      from: fromPath, to: adjustedPath),
      !fromBranch.isEmpty, !toBranch.isEmpty, fromBranch[0] < toBranch[0]
    {
      // Find the index in the adjusted path that needs to be decremented.
      if commonAncestor.count < adjustedPath.count {
        adjustedPath[commonAncestor.count] -= 1
      }
    }

    // 3. Insert the item at the new, correct location.
    globalInsertHandler(itemToMove, adjustedPath, adjustedIndex)
    userConfig.validateWithoutAlerts()

    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }

  private func findCommonAncestor(from path1: [Int], to path2: [Int]) -> ([Int], [Int], [Int])? {
    let minLength = min(path1.count, path2.count)
    var commonAncestor: [Int] = []
    for i in 0..<minLength {
      if path1[i] == path2[i] {
        commonAncestor.append(path1[i])
      } else {
        let fromBranch = Array(path1.suffix(from: i))
        let toBranch = Array(path2.suffix(from: i))
        return (commonAncestor, fromBranch, toBranch)
      }
    }
    let fromBranch = Array(path1.suffix(from: minLength))
    let toBranch = Array(path2.suffix(from: minLength))
    return (commonAncestor, fromBranch, toBranch)
  }

  private func removeItemFromGroup(_ group: inout Group, path: [Int]) {
    guard !path.isEmpty else { return }

    if path.count == 1 && path[0] < group.actions.count {
      group.actions.remove(at: path[0])
    } else if path.count > 1 {
      let firstIndex = path[0]
      if firstIndex < group.actions.count,
        case .group(var nestedGroup) = group.actions[firstIndex]
      {
        let remainingPath = Array(path.dropFirst())
        removeItemFromGroup(&nestedGroup, path: remainingPath)
        group.actions[firstIndex] = .group(nestedGroup)
      }
    }
  }

  private func insertItemIntoGroup(
    _ group: inout Group, item: ActionOrGroup, path: [Int], index: Int
  ) {
    if path.isEmpty {
      // Insert at root level
      let safeIndex = max(0, min(index, group.actions.count))
      group.actions.insert(item, at: safeIndex)
    } else if path.count == 1 {
      // Insert into direct child group
      let groupIndex = path[0]
      if groupIndex < group.actions.count,
        case .group(var targetGroup) = group.actions[groupIndex]
      {
        let safeIndex = max(0, min(index, targetGroup.actions.count))
        targetGroup.actions.insert(item, at: safeIndex)
        group.actions[groupIndex] = .group(targetGroup)
      }
    } else {
      // Navigate deeper into nested groups
      let firstIndex = path[0]
      if firstIndex < group.actions.count,
        case .group(var nestedGroup) = group.actions[firstIndex]
      {
        let remainingPath = Array(path.dropFirst())
        insertItemIntoGroup(&nestedGroup, item: item, path: remainingPath, index: index)
        group.actions[firstIndex] = .group(nestedGroup)
      }
    }
  }

  private func performDrop(at dropTarget: DropTarget) {
    guard let draggedItem = dragState.draggedItem,
      let fromPath = dragState.draggedFromPath,
      let globalRemoveHandler = dragState.globalRemoveHandler,
      let globalInsertHandler = dragState.globalInsertHandler
    else { return }

    globalRemoveHandler(fromPath)
    globalInsertHandler(draggedItem, dropTarget.path, dropTarget.index)

    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }
}

struct ConfigRowContainer: View {
  @Binding var item: ActionOrGroup
  let index: Int
  let currentPath: [Int]
  let isDragged: Bool
  @Binding var group: Group
  @ObservedObject var dragState: DragState
  @Binding var expandedGroups: Set<[Int]>
  let parentPath: [Int]
  let performDrop: (DropTarget) -> Void
  let startDrag: (ActionOrGroup, [Int]) -> Void
  let handleGlobalDragMove: (DragGesture.Value) -> Void
  let endDrag: () -> Void
  @EnvironmentObject var userConfig: UserConfig

  var body: some View {
    VStack(spacing: 0) {
      // Drop zone is now based on DropTarget
      DropZoneView(
        isActive: dragState.currentDropTarget == DropTarget(path: parentPath, index: index),
        performDrop: {
          performDrop(DropTarget(path: parentPath, index: index))
        }
      )
      .frame(height: isDragged ? 0 : generalPadding)  // Hide when dragging self

      if index < group.actions.count {
        ActionOrGroupRow(
          item: $item,
          path: currentPath,
          onDelete: {
            guard index < group.actions.count else { return }
            group.actions.remove(at: index)
          },
          onDuplicate: {
            guard index < group.actions.count else { return }
            group.actions.insert(group.actions[index], at: index)
          },
          expandedGroups: $expandedGroups,
          dragState: dragState
        )
        .opacity(isDragged ? 0.5 : 1.0)
        .scaleEffect(isDragged ? 0.97 : 1.0)
        .background(
          GeometryReader { geometry in
            Color.clear.preference(
              key: RowFrameKey.self, value: [currentPath: geometry.frame(in: .global)])
          })
      } else {
        // Invisible placeholder to maintain spacing
        Rectangle()
          .fill(Color.clear)
          .frame(height: 0)
      }
    }
    .gesture(
      userConfig.isRearrangeModeEnabled
        ? DragGesture(minimumDistance: 10, coordinateSpace: .global)
          .onChanged { value in
            if dragState.draggedFromPath == nil {
              withAnimation(Animation.easeOut(duration: 0.15)) {
                startDrag(item, currentPath)
              }
              NSCursor.closedHand.set()
            }
            if dragState.draggedFromPath == currentPath {
              handleGlobalDragMove(value)
            }
          }
          .onEnded { _ in
            if dragState.draggedFromPath == currentPath {
              withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.8)) {
                endDrag()
              }
            }
            NSCursor.arrow.set()
          }
        : nil
    )
  }
}

struct DropZoneView: View {
  let isActive: Bool
  let performDrop: () -> Void

  var body: some View {
    HStack {
      if isActive {
        // Apple guideline: Clear, prominent drop indicator
        HStack(spacing: 4) {
          Rectangle()
            .fill(Color.accentColor)
            .frame(height: 3)
            .cornerRadius(1.5)

          Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)

          Rectangle()
            .fill(Color.accentColor)
            .frame(height: 3)
            .cornerRadius(1.5)
        }
        .scaleEffect(isActive ? 1.0 : 0.8)
        .opacity(isActive ? 1.0 : 0.0)
        .animation(Animation.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        .onTapGesture {
          performDrop()
        }
      } else {
        Rectangle()
          .fill(Color.clear)
          .frame(height: 2)
      }
    }
  }
}

struct FloatingDraggedRow: View {
  let item: ActionOrGroup
  @ObservedObject var dragState: DragState
  let userConfig: UserConfig
  @Binding var expandedGroups: Set<[Int]>

  var body: some View {
    // Create a simplified preview that doesn't have interactive elements
    HStack(spacing: 8) {
      Image(systemName: "line.3.horizontal")
        .foregroundColor(.secondary)
        .font(.caption)

      switch item {
      case .action(let action):
        Text(action.key ?? "")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
          .frame(width: 32, height: 24)
          .background(Color(.controlBackgroundColor))
          .cornerRadius(5)

        Text(action.type.rawValue)
          .foregroundColor(.secondary)

        if let iconPath = action.iconPath {
          Image(systemName: iconPath.hasPrefix("SF:") ? String(iconPath.dropFirst(3)) : "app.fill")
            .frame(width: 24, height: 24)
        }

        Text(action.value)
          .truncationMode(.middle)
          .lineLimit(1)
          .foregroundColor(.primary)

        Spacer()

        Text(action.label ?? action.bestGuessDisplayName)
          .frame(width: 120)
          .foregroundColor(.secondary)

      case .group(let group):
        Text(group.key ?? "")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
          .frame(width: 32, height: 24)
          .background(Color(.controlBackgroundColor))
          .cornerRadius(5)

        if let iconPath = group.iconPath {
          Image(
            systemName: iconPath.hasPrefix("SF:") ? String(iconPath.dropFirst(3)) : "folder.fill"
          )
          .frame(width: 24, height: 24)
        }

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)

        Spacer()

        Text(group.label ?? "Group")
          .frame(width: 120)
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 40)
    // Apple guideline: Drag preview should be slightly transparent and elevated
    .scaleEffect(0.98)
    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.controlBackgroundColor))
        .opacity(0.95)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.accentColor, lineWidth: 2)
    )
    // Apple guideline: Smooth entrance animation
    .scaleEffect(dragState.isDragging ? 0.98 : 1.0)
    .animation(Animation.spring(response: 0.3, dampingFraction: 0.7), value: dragState.isDragging)
  }
}

struct ConfigEditorSheetView: View {
  @Binding var group: Group
  @EnvironmentObject var userConfig: UserConfig
  var isRoot: Bool = true
  @Binding var expandedGroups: Set<[Int]>
  @StateObject private var dragState = DragState()
  @State private var rowFrames: [[Int]: CGRect] = [:]
  @State private var isSheetPresented = false

  var body: some View {
    VStack(spacing: 0) {
      // Toolbar
      ConfigEditorToolbar(
        onSave: { userConfig.saveConfig() },
        onReload: { userConfig.reloadConfig() },
        onExpandAll: {
          withAnimation(.easeOut(duration: 0.1)) {
            expandAllGroups(in: group, parentPath: [])
          }
        },
        onCollapseAll: {
          withAnimation(.easeOut(duration: 0.1)) {
            expandedGroups.removeAll()
          }
        }
      )

      Divider()

      ScrollView {
      GroupContentView(
        group: $group, isRoot: isRoot, parentPath: [], expandedGroups: $expandedGroups
      )
      .environmentObject(dragState)
      .onPreferenceChange(RowFrameKey.self) { frames in
        self.rowFrames = frames
      }
      .onAppear {
        // Set up global cross-hierarchy handlers
        dragState.globalRemoveHandler = globalRemoveItem
        dragState.globalInsertHandler = globalInsertItem
        dragState.globalMoveHandler = globalMoveItem
        dragState.updateDropTarget = self.updateDropTarget
      }
      .background(
        KeyCapturingView(
          onCommandUp: moveItemUp,
          onCommandDown: moveItemDown,
          onArrowUp: navigateUp,
          onArrowDown: navigateDown,
          onCommandRight: expandItem,
          onCommandLeft: collapseItem
        )
      )
      .padding(
        EdgeInsets(
          top: generalPadding, leading: generalPadding,
          bottom: generalPadding, trailing: 0
        )
      )
      .onChange(of: dragState.focusedItemPath) { path in
        isSheetPresented = path != nil
      }
      }
    }
    .background(
      KeyEventHandler(dragState: dragState)
    )
    .overlay(
      GeometryReader { geometry in
        if let draggedItem = dragState.draggedItem,
          dragState.isDragging,
          dragState.dragLocation != .zero
        {
          FloatingDraggedRow(
            item: draggedItem,
            dragState: dragState,
            userConfig: userConfig,
            expandedGroups: $expandedGroups
          )
          .position(
            x: dragState.dragLocation.x - geometry.frame(in: .global).minX - 150,
            y: dragState.dragLocation.y - geometry.frame(in: .global).minY
          )
          .zIndex(1000)
          .allowsHitTesting(false)
        }
      }
    )
  }

  @ViewBuilder
  private func inspectorView() -> some View {
    if let path = dragState.focusedItemPath,
      let item = getItemAtPath(path, in: group)
    {
      let onDelete = {
        var newGroup = self.group
        removeItemFromGroup(&newGroup, path: path)
        self.group = newGroup
        // Dismiss the sheet by clearing the focus
        dragState.focusedItemPath = nil
      }

      let onDuplicate = {
        var newGroup = self.group
        let parentPath = Array(path.dropLast())
        // Duplicate *after* the current item
        let insertionIndex = path.last! + 1
        // 'item' is captured from the outer scope
        insertItemIntoGroup(
          &newGroup, item: item, path: parentPath, index: insertionIndex)
        self.group = newGroup

        // Update focus to the newly created item
        let newFocusPath = parentPath + [insertionIndex]
        dragState.focusedItemPath = newFocusPath
      }

      PropertyInspectorView(
        selectedItem: selectedItemBinding,
        onDelete: onDelete,
        onDuplicate: onDuplicate,
        onCancel: {
          // No need to do anything special on cancel from the inspector modal
        }
      )
    }
  }

  private var selectedItemBinding: Binding<ActionOrGroup?> {
    Binding<ActionOrGroup?>(
      get: {
        if let path = dragState.focusedItemPath {
          return getItemAtPath(path, in: group)
        }
        return nil
      },
      set: { newItem in
        if let path = dragState.focusedItemPath, let newItem = newItem {
          var newGroup = self.group
          setItemAtPath(&newGroup, path: path, item: newItem)
          self.group = newGroup
        }
      }
    )
  }

  private func setItemAtPath(_ group: inout Group, path: [Int], item: ActionOrGroup) {
    guard !path.isEmpty else { return }

    let index = path[0]
    guard index < group.actions.count else { return }

    if path.count == 1 {
      group.actions[index] = item
    } else {
      if case .group(var nestedGroup) = group.actions[index] {
        let remainingPath = Array(path.dropFirst())
        setItemAtPath(&nestedGroup, path: remainingPath, item: item)
        group.actions[index] = .group(nestedGroup)
      }
    }
  }

  private func updateDropTarget(at location: CGPoint) {
    var newTarget: DropTarget?
    var potentialAutoExpandPath: [Int]?  // The path to the group we might expand

    // Find the row being hovered over
    for (path, frame) in rowFrames.sorted(by: { $0.value.minY < $1.value.minY }) {
      if frame.contains(location) {
        let item = getItemAtPath(path, in: group)
        let isGroup = item?.isGroup ?? false
        let isExpanded = expandedGroups.contains(path)

        // Check if this is a candidate for auto-expansion
        if isGroup && !isExpanded {
          potentialAutoExpandPath = path
        }

        // --- Existing logic to determine drop target ---
        let targetMidY = frame.minY + (frame.height / 2)

        if location.y < targetMidY {
          // Drop ABOVE the item
          newTarget = DropTarget(path: Array(path.dropLast()), index: path.last!)
        } else {
          if isGroup && isExpanded {
            // Drop INTO the expanded group
            newTarget = DropTarget(path: path, index: 0)
          } else {
            // Drop BELOW the item
            newTarget = DropTarget(path: Array(path.dropLast()), index: path.last! + 1)
          }
        }
        break  // Found the target row
      }
    }

    // --- Update drop target state ---
    if newTarget != dragState.currentDropTarget {
      DispatchQueue.main.async {
        dragState.currentDropTarget = newTarget
      }
    }

    // --- Handle auto-expansion logic ---
    // If we're not hovering over the same group as before, cancel the old timer.
    if dragState.hoveredGroupPath != potentialAutoExpandPath {
      dragState.autoExpandTimer?.invalidate()
      dragState.autoExpandTimer = nil
      dragState.hoveredGroupPath = potentialAutoExpandPath
    }

    // If we are hovering over a new group and the timer isn't running yet, start it.
    if let pathToExpand = potentialAutoExpandPath, dragState.autoExpandTimer == nil {
      dragState.autoExpandTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
        // Use withAnimation for a smooth expansion
        self.expandedGroups.insert(pathToExpand)
        // Give haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
      }
    }
  }

  // Global functions for cross-hierarchy operations
  private func globalRemoveItem(fromPath: [Int]) {
    // Update expanded groups paths that come after the removed item
    var updatedExpandedGroups = Set<[Int]>()
    for expandedPath in expandedGroups {
      if shouldAdjustPath(expandedPath, afterRemovingAt: fromPath) {
        if let adjusted = adjustPathAfterRemoval(expandedPath, removedPath: fromPath) {
          updatedExpandedGroups.insert(adjusted)
        }
      } else {
        updatedExpandedGroups.insert(expandedPath)
      }
    }

    removeItemFromGroup(&group, path: fromPath)
    expandedGroups = updatedExpandedGroups
  }

  private func globalInsertItem(item: ActionOrGroup, path: [Int], index: Int) {
    // Update expanded groups paths that come after the insertion point
    var updatedExpandedGroups = Set<[Int]>()
    for expandedPath in expandedGroups {
      if shouldAdjustPath(expandedPath, afterInsertingAt: path, index: index) {
        if let adjusted = adjustPathAfterInsertion(
          expandedPath, insertPath: path, insertIndex: index)
        {
          updatedExpandedGroups.insert(adjusted)
        }
      } else {
        updatedExpandedGroups.insert(expandedPath)
      }
    }

    insertItemIntoGroup(&group, item: item, path: path, index: index)
    expandedGroups = updatedExpandedGroups
  }

  private func globalMoveItem(fromPath: [Int], toPath: [Int], toIndex: Int) {
    // Get the item to move
    if let item = getItemAtPath(fromPath, in: group) {
      // If moving into a group, ensure it's expanded first
      if !toPath.isEmpty {
        ensureGroupExpanded(at: toPath)

        // Wait for expansion animation to complete before moving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          self.performActualMove(item: item, fromPath: fromPath, toPath: toPath, toIndex: toIndex)
        }
      } else {
        // No group expansion needed, move immediately
        performActualMove(item: item, fromPath: fromPath, toPath: toPath, toIndex: toIndex)
      }
    }
  }

  private func performActualMove(item: ActionOrGroup, fromPath: [Int], toPath: [Int], toIndex: Int)
  {
    // Remove from source
    globalRemoveItem(fromPath: fromPath)
    // Insert at destination
    globalInsertItem(item: item, path: toPath, index: toIndex)

    // Calculate the correct focus path after the move
    let newFocusPath = toPath + [toIndex]

    // Set focus immediately after the move
    dragState.focusedItemPath = newFocusPath
    userConfig.validateWithoutAlerts()
  }

  private func ensureGroupExpanded(at path: [Int]) {
    // Expand the target group if it's not already expanded
    if !expandedGroups.contains(path) {
      expandedGroups.insert(path)
    }
  }

  private func getItemAtPath(_ path: [Int], in group: Group) -> ActionOrGroup? {
    guard !path.isEmpty else { return nil }

    var currentGroup = group
    for (index, pathComponent) in path.enumerated() {
      guard pathComponent < currentGroup.actions.count else { return nil }

      let item = currentGroup.actions[pathComponent]

      if index == path.count - 1 {
        // This is the final path component, return the item
        return item
      } else {
        // Need to go deeper, so this must be a group
        if case .group(let nestedGroup) = item {
          currentGroup = nestedGroup
        } else {
          return nil  // Path goes deeper but current item is not a group
        }
      }
    }

    return nil
  }

  // MARK: - Keyboard Navigation

  private func moveItemUp() {
    guard let focusedPath = dragState.focusedItemPath else {
      return
    }

    // Calculate the previous position in a flattened list view
    if let (targetPath, targetIndex) = getPreviousPosition(from: focusedPath) {
      dragState.globalMoveHandler?(focusedPath, targetPath, targetIndex)
    }
  }

  private func moveItemDown() {
    guard let focusedPath = dragState.focusedItemPath else {
      return
    }

    // Calculate the next position in a flattened list view
    if let (targetPath, targetIndex) = getNextPosition(from: focusedPath) {
      dragState.globalMoveHandler?(focusedPath, targetPath, targetIndex)
    }
  }

  private func navigateUp() {
    if let currentPath = dragState.focusedItemPath {
      if let previousPath = getPreviousNavigationPath(from: currentPath) {
        dragState.focusedItemPath = previousPath
      }
    } else {
      // If no item is focused, focus the first item
      if !group.actions.isEmpty {
        dragState.focusedItemPath = [0]
      }
    }
  }

  private func navigateDown() {
    if let currentPath = dragState.focusedItemPath {
      if let nextPath = getNextNavigationPath(from: currentPath) {
        dragState.focusedItemPath = nextPath
      }
    } else {
      // If no item is focused, focus the first item
      if !group.actions.isEmpty {
        dragState.focusedItemPath = [0]
      }
    }
  }

  private func expandItem() {
    guard let focusedPath = dragState.focusedItemPath else {
      return
    }

    // Get the item at the focused path
    if let item = getItemAtPath(focusedPath, in: group) {
      if case .group = item {
        // Add to expanded groups
        expandedGroups.insert(focusedPath)
      }
    }
  }

  private func collapseItem() {
    guard let focusedPath = dragState.focusedItemPath else {
      return
    }

    // Get the item at the focused path
    if let item = getItemAtPath(focusedPath, in: group) {
      if case .group = item {
        // Remove from expanded groups
        expandedGroups.remove(focusedPath)
      }
    }
  }

  private func getPreviousPosition(from path: [Int]) -> ([Int], Int)? {
    guard let currentIndex = path.last else { return nil }

    if currentIndex > 0 {
      // Check if the previous item is a group - if so, move to the end of that group
      let parentPath = Array(path.dropLast())
      let prevIndex = currentIndex - 1

      if let parentGroup = getGroupAtPath(parentPath) {
        let prevItem = parentGroup.actions[prevIndex]

        if case .group(let prevGroup) = prevItem {
          // Move to the end of the previous group
          let prevGroupPath = parentPath + [prevIndex]
          return (prevGroupPath, prevGroup.actions.count)
        } else {
          // Move up within the same group to the previous regular item
          return (parentPath, prevIndex)
        }
      }
    } else {
      // At the beginning of current group - move out to parent level
      let parentPath = Array(path.dropLast())

      if parentPath.isEmpty {
        // Already at root level, first item
        return nil
      }

      // Move to the parent level, just before this group
      if let parentIndex = parentPath.last {
        let grandParentPath = Array(parentPath.dropLast())
        return (grandParentPath, parentIndex)
      }
    }

    return nil
  }

  private func getNextPosition(from path: [Int]) -> ([Int], Int)? {
    guard let currentIndex = path.last else { return nil }
    let parentPath = Array(path.dropLast())

    // Get the parent group to check bounds
    if let parentGroup = getGroupAtPath(parentPath) {
      if currentIndex < parentGroup.actions.count - 1 {
        // Check if the next item is a group - if so, move into it
        let nextIndex = currentIndex + 1
        let nextItem = parentGroup.actions[nextIndex]

        if case .group = nextItem {
          // Move into the next group at position 0
          let nextItemPath = parentPath + [nextIndex]
          return (nextItemPath, 0)
        } else {
          // Move down within the same group to the next regular item
          return (parentPath, nextIndex)
        }
      } else {
        // At the end of current group - try to move out to parent level
        if !parentPath.isEmpty, let parentIndex = parentPath.last {
          let grandParentPath = Array(parentPath.dropLast())
          if let grandParentGroup = getGroupAtPath(grandParentPath) {
            let nextIndex = parentIndex + 1
            if nextIndex <= grandParentGroup.actions.count {
              return (grandParentPath, nextIndex)
            }
          }
        }
      }
    }

    return nil
  }

  private func getGroupAtPath(_ path: [Int]) -> Group? {
    if path.isEmpty {
      return group
    }

    var currentGroup = group
    for index in path {
      guard index < currentGroup.actions.count else { return nil }

      if case .group(let nestedGroup) = currentGroup.actions[index] {
        currentGroup = nestedGroup
      } else {
        return nil
      }
    }

    return currentGroup
  }

  private func shouldAdjustPath(_ path: [Int], afterRemovingAt removedPath: [Int]) -> Bool {
    // Check if paths share a common parent and if adjustment is needed
    guard path.count > 0 && removedPath.count > 0 else { return false }

    // Compare paths level by level
    for i in 0..<min(path.count, removedPath.count) {
      if path[i] != removedPath[i] {
        // Paths diverge before the removed item level
        return i > 0 && path[i] > removedPath[i]
      }
    }

    // Path is a parent of or equal to removed path
    return false
  }

  private func adjustPathAfterRemoval(_ path: [Int], removedPath: [Int]) -> [Int]? {
    var adjusted = path

    // Find the level where adjustment is needed
    for i in 0..<min(path.count, removedPath.count) {
      if i == removedPath.count - 1 && path[i] > removedPath[i] {
        // Adjust this index down by 1
        adjusted[i] -= 1
        return adjusted
      }
    }

    return adjusted
  }

  private func shouldAdjustPath(_ path: [Int], afterInsertingAt insertPath: [Int], index: Int)
    -> Bool
  {
    guard path.count > 0 && insertPath.count > 0 else { return false }

    // If inserting at root level
    if insertPath.isEmpty {
      return path.count > 0 && path[0] >= index
    }

    // Compare paths level by level
    for i in 0..<min(path.count, insertPath.count) {
      if path[i] != insertPath[i] {
        return false
      }
    }

    // Check if we need to adjust based on insertion index
    if path.count > insertPath.count {
      return path[insertPath.count] >= index
    }

    return false
  }

  private func adjustPathAfterInsertion(_ path: [Int], insertPath: [Int], insertIndex: Int)
    -> [Int]?
  {
    var adjusted = path

    if insertPath.isEmpty && path.count > 0 && path[0] >= insertIndex {
      adjusted[0] += 1
      return adjusted
    }

    if path.count > insertPath.count && path[insertPath.count] >= insertIndex {
      adjusted[insertPath.count] += 1
      return adjusted
    }

    return adjusted
  }

  private func removeItemFromGroup(_ group: inout Group, path: [Int]) {
    guard !path.isEmpty else { return }

    if path.count == 1 && path[0] < group.actions.count {
      group.actions.remove(at: path[0])
    } else if path.count > 1 {
      let firstIndex = path[0]
      if firstIndex < group.actions.count,
        case .group(var nestedGroup) = group.actions[firstIndex]
      {
        let remainingPath = Array(path.dropFirst())
        removeItemFromGroup(&nestedGroup, path: remainingPath)
        group.actions[firstIndex] = .group(nestedGroup)
      }
    }
  }

  private func insertItemIntoGroup(
    _ group: inout Group, item: ActionOrGroup, path: [Int], index: Int
  ) {
    if path.isEmpty {
      // Insert at root level
      let safeIndex = max(0, min(index, group.actions.count))
      group.actions.insert(item, at: safeIndex)
    } else if path.count == 1 {
      // Insert into direct child group
      let groupIndex = path[0]
      if groupIndex < group.actions.count,
        case .group(var targetGroup) = group.actions[groupIndex]
      {
        let safeIndex = max(0, min(index, targetGroup.actions.count))
        targetGroup.actions.insert(item, at: safeIndex)
        group.actions[groupIndex] = .group(targetGroup)
      }
    } else {
      // Navigate deeper into nested groups
      let firstIndex = path[0]
      if firstIndex < group.actions.count,
        case .group(var nestedGroup) = group.actions[firstIndex]
      {
        let remainingPath = Array(path.dropFirst())
        insertItemIntoGroup(&nestedGroup, item: item, path: remainingPath, index: index)
        group.actions[firstIndex] = .group(nestedGroup)
      }
    }
  }

  private func getPreviousNavigationPath(from path: [Int]) -> [Int]? {
    // Flatten the hierarchy and find the previous visible item
    let allPaths = getAllVisiblePaths()
    guard let currentIndex = allPaths.firstIndex(of: path) else { return nil }
    return currentIndex > 0 ? allPaths[currentIndex - 1] : nil
  }

  private func getNextNavigationPath(from path: [Int]) -> [Int]? {
    // Flatten the hierarchy and find the next visible item
    let allPaths = getAllVisiblePaths()
    guard let currentIndex = allPaths.firstIndex(of: path) else { return nil }
    return currentIndex < allPaths.count - 1 ? allPaths[currentIndex + 1] : nil
  }

  private func getAllVisiblePaths() -> [[Int]] {
    var paths: [[Int]] = []
    collectVisiblePaths(from: group, parentPath: [], into: &paths)
    return paths
  }

  private func collectVisiblePaths(from group: Group, parentPath: [Int], into paths: inout [[Int]])
  {
    for (index, item) in group.actions.enumerated() {
      let currentPath = parentPath + [index]
      paths.append(currentPath)

      if case .group(let nestedGroup) = item {
        // Only collect paths from expanded groups
        if expandedGroups.contains(currentPath) {
          collectVisiblePaths(from: nestedGroup, parentPath: currentPath, into: &paths)
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

struct ActionOrGroupRow: View {
  @Binding var item: ActionOrGroup
  var path: [Int]
  let onDelete: () -> Void
  let onDuplicate: () -> Void
  @EnvironmentObject var userConfig: UserConfig
  @Binding var expandedGroups: Set<[Int]>
  @ObservedObject var dragState: DragState
  @FocusState private var isKeyFocused: Bool
  @FocusState private var isLabelFocused: Bool
  @State private var labelFieldAnchor: NSView? = nil
  @State private var showInspectorPopover = false

  private var isFocused: Bool {
    dragState.focusedItemPath == path
  }

  private var rowBackgroundColor: Color {
    if isFocused {
      return Color.accentColor.opacity(0.2)  // Selected
    }
    if dragState.hoveredItemPath == path {
      return Color.primary.opacity(0.1)  // Hovered
    }
    return Color.clear  // Default
  }

  private func openSheet() {
    dragState.focusedItemPath = path
  }

  var body: some View {
    let rowContent =
      VStack {
        switch item {
        case .action:
          ActionRow(
            action: Binding(
              get: {
                if case .action(let action) = item {
                  return action
                }
                return Action(key: "", type: .application, value: "")
              },
              set: { newAction in
                item = .action(newAction)
              }
            ),
            path: path,
            dragState: dragState
          )
        case .group:
          GroupRow(
            group: Binding(
              get: {
                if case .group(let group) = item {
                  return group
                }
                return Group(key: "", actions: [])
              },
              set: { newGroup in
                item = .group(newGroup)
              }
            ),
            path: path,
            expandedGroups: $expandedGroups,
            dragState: dragState
          )
        }
      }
      .onHover { hovering in
        if hovering {
          dragState.hoveredItemPath = path
        } else if dragState.hoveredItemPath == path {
          dragState.hoveredItemPath = nil
        }
      }
      .onTapGesture {
        dragState.focusedItemPath = path
        // If the item is a group and is already focused, toggle its expansion
        if case .group = item, isFocused {
          withAnimation(.easeOut(duration: 0.1)) {
            if expandedGroups.contains(path) {
              expandedGroups.remove(path)
            } else {
              expandedGroups.insert(path)
            }
          }
        }
      }

    HStack {
      rowContent
      Spacer()
    }
    .background(
      PopoverPresenter(
        isPresented: $showInspectorPopover,
        content: {
          PropertyInspectorView(
            selectedItem: Binding<ActionOrGroup?>(
              get: { item },
              set: { newItem in
                if let newItem = newItem {
                  item = newItem
                }
              }
            ),
            onDelete: onDelete,
            onDuplicate: onDuplicate,
            onCancel: {
              // Cancel without saving changes
              showInspectorPopover = false
            }
          )
        },
        preferredEdge: .minY,
        anchorView: labelFieldAnchor,
        onDismiss: {
          // Popover was dismissed without clicking Done
          showInspectorPopover = false
        }
      )
    )
  }
}

struct IconPickerMenu: View {
  @Binding var item: ActionOrGroup
  @State private var iconPickerPresented = false

  var body: some View {
    Menu {
      Button("App Icon") {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle, .application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
          switch item {
          case .action(var action):
            action.iconPath = panel.url?.path
            item = .action(action)
          case .group(var group):
            group.iconPath = panel.url?.path
            item = .group(group)
          }
        }
      }
      Button("Symbol") {
        iconPickerPresented = true
      }
      Divider()
      Button("✕ Clear") {
        switch item {
        case .action(var action):
          action.iconPath = nil
          item = .action(action)
        case .group(var group):
          group.iconPath = nil
          item = .group(group)
        }
      }
    } label: {
      actionIcon(item: item, iconSize: NSSize(width: 24, height: 24))
    }
    .buttonStyle(PlainButtonStyle())
    .sheet(isPresented: $iconPickerPresented) {
      switch item {
      case .action(var action):
        SymbolPicker(
          symbol: Binding(
            get: { action.iconPath },
            set: { newPath in
              action.iconPath = newPath
              item = .action(action)
            }
          ))
      case .group(var group):
        SymbolPicker(
          symbol: Binding(
            get: { group.iconPath },
            set: { newPath in
              group.iconPath = newPath
              item = .group(group)
            }
          ))
      }
    }
  }
}

struct ActionRow: View {
  @Binding var action: Action
  var path: [Int]
  @ObservedObject var dragState: DragState
  @FocusState private var isLabelFocused: Bool
  @EnvironmentObject var userConfig: UserConfig
  @State private var labelFieldAnchor: NSView?
  @State private var showInspectorPopover = false

  private var isFocused: Bool {
    dragState.focusedItemPath == path
  }

  private var rowBackgroundColor: Color {
    if isFocused {
      return Color.accentColor.opacity(0.2)  // Selected
    }
    if dragState.hoveredItemPath == path {
      return Color.primary.opacity(0.1)  // Hovered
    }
    return Color.clear  // Default
  }

  var body: some View {
    HStack(spacing: generalPadding) {
      Spacer().frame(width: 30)

      KeyButton(
        text: Binding(
          get: { action.key ?? "" },
          set: { action.key = $0 }
        ), placeholder: "Key", validationError: validationErrorForKey,
        onKeyChanged: { _, _ in userConfig.finishEditingKey() }
      )

      IconPickerMenu(
        item: Binding(
          get: { .action(action) },
          set: { newItem in
            if case .action(let newAction) = newItem {
              action = newAction
            }
          }
        )
      )
      .padding(.leading, 32)

      LabelTextField(
        text: $action.label._orEmpty(),
        prompt: action.bestGuessDisplayName,
        isLabelFocused: $isLabelFocused,
        labelFieldAnchor: $labelFieldAnchor
      )
      .onChange(of: isLabelFocused) { focused in
        if focused {
          showInspectorPopover = true
          dragState.focusedItemPath = path
        }
      }

      // 6-dot drag handle - always present but only visible when hovering
      Image(systemName: "line.3.horizontal")
        .foregroundColor(.secondary)
        .font(.caption)
        .padding(.horizontal, 8)
        .opacity(dragState.hoveredItemPath == path ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.15), value: dragState.hoveredItemPath)
        .allowsHitTesting(dragState.hoveredItemPath == path)
        .onHover { hovering in
          if hovering {
            NSCursor.openHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
        .gesture(
          DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { _ in
              NSCursor.closedHand.set()
            }
            .onEnded { _ in
              NSCursor.openHand.set()
            }
        )

      Spacer()
    }
    .background(
      Rectangle()
        .fill(rowBackgroundColor)
        .cornerRadius(6)
    )
    .background(
      PopoverPresenter(
        isPresented: $showInspectorPopover,
        content: {
          PropertyInspectorView(
            selectedItem: Binding<ActionOrGroup?>(
              get: { .action(action) },
              set: { newItem in
                if case .action(let newAction) = newItem {
                  action = newAction
                }
              }
            ),
            onDelete: {},
            onDuplicate: {},
            onCancel: {
              showInspectorPopover = false
            }
          )
        },
        preferredEdge: .minY,
        anchorView: labelFieldAnchor,
        onDismiss: {
          showInspectorPopover = false
        }
      )
    )
  }

  private var validationErrorForKey: ValidationErrorType? {
    guard !path.isEmpty else { return nil }

    // Find validation errors for this item
    let errors = userConfig.validationErrors.filter { error in
      error.path == path
    }

    if let error = errors.first {
      return error.type
    }

    return nil
  }
}

struct GroupRow: View {
  @Binding var group: Group
  var path: [Int]
  @Binding var expandedGroups: Set<[Int]>
  @FocusState private var isLabelFocused: Bool
  @ObservedObject var dragState: DragState
  @EnvironmentObject var userConfig: UserConfig
  @State private var labelFieldAnchor: NSView?
  @State private var showInspectorPopover = false

  private var isFocused: Bool {
    dragState.focusedItemPath == path
  }

  private var rowBackgroundColor: Color {
    if isFocused {
      return Color.accentColor.opacity(0.2)  // Selected
    }
    if dragState.hoveredItemPath == path {
      return Color.primary.opacity(0.1)  // Hovered
    }
    return Color.clear  // Default
  }

  var body: some View {
    LazyVStack(spacing: generalPadding) {
      HStack(spacing: generalPadding) {
        Button(
          role: .none,
          action: {
            withAnimation(.easeOut(duration: 0.1)) {
              if expandedGroups.contains(path) {
                expandedGroups.remove(path)
              } else {
                expandedGroups.insert(path)
              }
            }
          }
        ) {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(expandedGroups.contains(path) ? 90 : 0))
            .padding(4)
        }.buttonStyle(.plain)
          .frame(width: expandButtonWidth, alignment: .center)

        KeyButton(
          text: Binding(
            get: { self.group.key ?? "" },
            set: { self.group.key = $0 }
          ),
          placeholder: "Group Key",
          validationError: validationErrorForKey,
          onKeyChanged: { maybePrev, value in
            if maybePrev != value, let prev = maybePrev {
              Defaults[.groupShortcuts].remove(prev)
              KeyboardShortcuts.reset([KeyboardShortcuts.Name("group-\(prev)")])
            }
            userConfig.finishEditingKey()
          }
        )
        .onTapGesture {
          if !expandedGroups.contains(path) {
            withAnimation(.easeOut(duration: 0.1)) {
              expandedGroups.insert(path)
            }
          }
        }

        IconPickerMenu(
          item: Binding(
            get: { .group(self.group) },
            set: { newItem in
              if case .group(let newGroup) = newItem {
                self.group = newGroup
              }
            }
          )
        )
        .padding(.leading, 32)
        .onTapGesture {
          if !expandedGroups.contains(path) {
            withAnimation(.easeOut(duration: 0.1)) {
              expandedGroups.insert(path)
            }
          }
        }

        LabelTextField(
          text: $group.label._orEmpty(),
          prompt: "Label",
          isLabelFocused: $isLabelFocused,
          labelFieldAnchor: $labelFieldAnchor
        )
        .background(ViewExtractor(nsView: $labelFieldAnchor))
        .onChange(of: isLabelFocused) { focused in
          if focused {
            showInspectorPopover = true
            dragState.focusedItemPath = path
            if !expandedGroups.contains(path) {
              withAnimation(.easeOut(duration: 0.1)) {
                expandedGroups.insert(path)
              }
            }
          }
        }

        // 6-dot drag handle - always present but only visible when hovering
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.secondary)
          .font(.caption)
          .padding(.horizontal, 8)
          .opacity(dragState.hoveredItemPath == path ? 1.0 : 0.0)
          .animation(.easeInOut(duration: 0.15), value: dragState.hoveredItemPath)
          .allowsHitTesting(dragState.hoveredItemPath == path)
          .onHover { hovering in
            if hovering {
              NSCursor.openHand.set()
            } else {
              NSCursor.arrow.set()
            }
          }
          .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
              .onChanged { _ in
                NSCursor.closedHand.set()
              }
              .onEnded { _ in
                NSCursor.openHand.set()
              }
          )

        Spacer(minLength: 0)
      }
      .background(
        Rectangle()
          .fill(rowBackgroundColor)
          .cornerRadius(6)
      )
    }
    .padding(.horizontal, 0)
    .background(
      PopoverPresenter(
        isPresented: $showInspectorPopover,
        content: {
          PropertyInspectorView(
            selectedItem: Binding<ActionOrGroup?>(
              get: { .group(group) },
              set: { newItem in
                if case .group(let newGroup) = newItem {
                  group = newGroup
                }
              }
            ),
            onDelete: {},
            onDuplicate: {},
            onCancel: {
              showInspectorPopover = false
            }
          )
        },
        preferredEdge: .minY,
        anchorView: labelFieldAnchor,
        onDismiss: {
          showInspectorPopover = false
        }
      )
    )
  }

  private var validationErrorForKey: ValidationErrorType? {
    guard !path.isEmpty else { return nil }

    // Find validation errors for this item
    let errors = userConfig.validationErrors.filter { error in
      error.path == path
    }

    if let error = errors.first {
      return error.type
    }

    return nil
  }
}

struct ViewExtractor: NSViewRepresentable {
  @Binding var nsView: NSView?
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      self.nsView = view.superview
    }
    return view
  }
  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      self.nsView = nsView.superview
    }
  }
}

#Preview {
  let group = Group(
    key: "",
    actions: [
      // Level 1 actions
      .action(
        Action(key: "t", type: .application, value: "/Applications/WezTerm.app")
      ),
      .action(
        Action(key: "f", type: .application, value: "/Applications/Firefox.app")
      ),
      // Level 1 group with actions
      .group(
        Group(
          key: "b",
          actions: [
            .action(
              Action(
                key: "c", type: .application,
                value: "/Applications/Google Chrome.app"
              )),
            .action(
              Action(
                key: "s", type: .application, value: "/Applications/Safari.app"
              )
            ),
          ]
        )),
    ]
  )

  let userConfig = UserConfig()

  return ConfigEditorSheetView(group: .constant(group), expandedGroups: .constant(Set<[Int]>()))
    .frame(width: 720, height: 500)
    .environmentObject(userConfig)
}

extension ActionOrGroup {
  var isGroup: Bool {
    if case .group = self {
      return true
    }
    return false
  }
}

// Define a new preference key to collect row frames
struct RowFrameKey: PreferenceKey {
  static var defaultValue: [[Int]: CGRect] = [:]
  static func reduce(value: inout [[Int]: CGRect], nextValue: () -> [[Int]: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

// This is a struct to provide an environment value
struct RowFramesKey: EnvironmentKey {
  static let defaultValue: [[Int]: CGRect] = [:]
}

extension EnvironmentValues {
  var rowFrames: [[Int]: CGRect] {
    get { self[RowFramesKey.self] }
    set { self[RowFramesKey.self] = newValue }
  }
}

struct PropertyInspectorView: View {
  @Binding var selectedItem: ActionOrGroup?
  @Environment(\.dismiss) private var dismiss
  let onDelete: () -> Void
  let onDuplicate: () -> Void
  let onCancel: () -> Void
  @State private var showingDeleteConfirmation = false
  @State private var localItem: ActionOrGroup?

  var body: some View {
    VStack(spacing: 0) {
      // Top bar with close button
      HStack {
        Spacer()
        Button(action: {
          if let localItem = localItem {
            selectedItem = localItem
          }
          onCancel()
        }) {
          Image(systemName: "xmark")
            .foregroundColor(.secondary)
            .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(.borderless)
        .help("Close")
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)

      VStack(spacing: 16) {
        if let item = localItem {
          switch item {
          case .action(let action):
            ActionDetailView(
              action: Binding(
                get: { action },
                set: { newAction in
                  self.localItem = .action(newAction)
                }
              ),
              onDelete: {
                showingDeleteConfirmation = true
              },
              onDuplicate: onDuplicate
            )
          case .group(let group):
            GroupDetailView(
              group: Binding(
                get: { group },
                set: { newGroup in
                  self.localItem = .group(newGroup)
                }
              ),
              onDelete: {
                showingDeleteConfirmation = true
              },
              onDuplicate: onDuplicate
            )
          }

        } else {
          VStack(spacing: 8) {
            Image(systemName: "gear")
              .font(.system(size: 32))
              .foregroundColor(.secondary)
            Text("Select an item to see its properties.")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .frame(minWidth: 300, maxWidth: 400, minHeight: 200, maxHeight: 600)
    .onAppear {
      localItem = selectedItem
    }
    .onChange(of: selectedItem) { oldValue, newValue in
      if localItem == nil || oldValue != newValue {
        localItem = newValue
      }
    }
    .alert(
      "Are you sure you want to delete this item?", isPresented: $showingDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) {
        onDelete()
        dismiss()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This action cannot be undone.")
    }
  }
}

struct GroupDetailView: View {
  @Binding var group: Group
  @FocusState private var isLabelFocused: Bool
  @State private var iconPickerPresented = false
  let onDelete: () -> Void
  let onDuplicate: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Basic Information Section
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Basic Information")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }

        HStack(alignment: .center, spacing: 12) {
          Menu {
            Button("App Icon") {
              let panel = NSOpenPanel()
              panel.allowedContentTypes = [.applicationBundle, .application]
              panel.canChooseFiles = true
              panel.canChooseDirectories = true
              panel.allowsMultipleSelection = false
              panel.directoryURL = URL(fileURLWithPath: "/Applications")
              if panel.runModal() == .OK {
                var updatedGroup = group
                updatedGroup.iconPath = panel.url?.path
                group = updatedGroup
              }
            }
            Button("Symbol") {
              iconPickerPresented = true
            }
            Divider()
            Button("✕ Clear") {
              var updatedGroup = group
              updatedGroup.iconPath = nil
              group = updatedGroup
            }
          } label: {
            actionIcon(item: .group(group), iconSize: NSSize(width: 60, height: 60))
          }
          .buttonStyle(PlainButtonStyle())
          .frame(width: 60, height: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text("Label")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)

            SelectAllTextField(
              text: $group.label._orEmpty(), isFocused: $isLabelFocused, placeholder: "Group"
            )
            .frame(height: 22)

            // Delete and copy buttons under label field
            HStack(spacing: 8) {
              Button(action: onDelete) {
                Text("Delete")
              }
              .buttonStyle(.bordered)
              .controlSize(.small)

              Button(action: onDuplicate) {
                Text("Duplicate")
              }
              .buttonStyle(.bordered)
              .controlSize(.small)

              Spacer()
            }
            .padding(.top, 4)
          }
        }
      }
      .padding(.horizontal, 4)

      Divider()

      // Shortcut Section
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Direct Access Shortcut")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }

        VStack(alignment: .leading, spacing: 8) {
          Text(
            "Optionally, set a global shortcut to open this group directly, bypassing the main window."
          )
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          if let key = group.key, !key.isEmpty {
            KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name("group-\(key)")) { shortcut in
              if shortcut != nil {
                Defaults[.groupShortcuts].insert(key)
              } else {
                Defaults[.groupShortcuts].remove(key)
              }
              (NSApplication.shared.delegate as! AppDelegate).registerGlobalShortcuts()
            }
          } else {
            Text("Set a 'Group Key' in the main list to enable direct access shortcuts.")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
              .italic()
          }
        }
      }
      .padding(.horizontal, 4)

      Spacer()
    }
    .onAppear {
      isLabelFocused = true
    }
    .sheet(isPresented: $iconPickerPresented) {
      SymbolPicker(
        symbol: Binding(
          get: { group.iconPath },
          set: { newPath in
            var updatedGroup = group
            updatedGroup.iconPath = newPath
            group = updatedGroup
          }
        ))
    }
  }
}

struct ActionDetailView: View {
  @Binding var action: Action
  @FocusState private var isLabelFocused: Bool
  @State private var localValues: [Type: String] = [:]
  @State private var iconPickerPresented = false
  let onDelete: () -> Void
  let onDuplicate: () -> Void

  private var currentBestGuessDisplayName: String {
    let currentValue = action.value
    switch action.type {
    case .application:
      return currentValue.isEmpty
        ? "Application"
        : (currentValue as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
    case .command:
      return currentValue.isEmpty
        ? "Command" : currentValue.components(separatedBy: " ").first ?? currentValue
    case .folder:
      return currentValue.isEmpty ? "Folder" : (currentValue as NSString).lastPathComponent
    case .url:
      return currentValue.isEmpty ? "URL" : "URL"
    default:
      return currentValue.isEmpty ? "Action" : currentValue
    }
  }

  private func selectType(_ newType: Type) {
    let oldType = action.type

    // Save the current value for the old type
    localValues[oldType] = action.value

    // Load the saved value for the new type, or use empty string if none
    let savedValue = localValues[newType] ?? ""
    var updatedAction = action
    updatedAction.type = newType
    updatedAction.value = savedValue
    action = updatedAction
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Basic Information Section
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Basic Information")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }

        HStack(alignment: .center, spacing: 12) {
          Menu {
            Button("App Icon") {
              let panel = NSOpenPanel()
              panel.allowedContentTypes = [.applicationBundle, .application]
              panel.canChooseFiles = true
              panel.canChooseDirectories = true
              panel.allowsMultipleSelection = false
              panel.directoryURL = URL(fileURLWithPath: "/Applications")
              if panel.runModal() == .OK {
                var updatedAction = action
                updatedAction.iconPath = panel.url?.path
                action = updatedAction
              }
            }
            Button("Symbol") {
              iconPickerPresented = true
            }
            Divider()
            Button("✕ Clear") {
              var updatedAction = action
              updatedAction.iconPath = nil
              action = updatedAction
            }
          } label: {
            actionIcon(item: .action(action), iconSize: NSSize(width: 60, height: 60))
          }
          .buttonStyle(PlainButtonStyle())
          .frame(width: 60, height: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text("Label")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)

            SelectAllTextField(
              text: $action.label._orEmpty(), isFocused: $isLabelFocused,
              placeholder: currentBestGuessDisplayName
            )
            .frame(height: 22)

            // Delete and copy buttons under label field
            HStack(spacing: 8) {
              Button(action: onDelete) {
                Text("Delete")
              }
              .buttonStyle(.bordered)
              .controlSize(.small)

              Button(action: onDuplicate) {
                Text("Duplicate")
              }
              .buttonStyle(.bordered)
              .controlSize(.small)

              Spacer()
            }
            .padding(.top, 4)
          }
        }
      }
      .padding(.horizontal, 4)

      Divider()

      // Type Selection Section
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Action Type")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }

        HStack(spacing: 12) {
          TypeButton(
            type: .application,
            icon: "app.fill",
            label: "Application",
            isSelected: action.type == .application,
            onTap: { selectType(.application) }
          )

          TypeButton(
            type: .url,
            icon: "link",
            label: "URL",
            isSelected: action.type == .url,
            onTap: { selectType(.url) }
          )

          TypeButton(
            type: .command,
            icon: "terminal",
            label: "Command",
            isSelected: action.type == .command,
            onTap: { selectType(.command) }
          )

          TypeButton(
            type: .folder,
            icon: "folder",
            label: "Folder",
            isSelected: action.type == .folder,
            onTap: { selectType(.folder) }
          )
        }
      }
      .padding(.horizontal, 4)

      Divider()

      // Configuration Section
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Configuration")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
        }

        VStack(alignment: .leading, spacing: 8) {
          switch action.type {
          case .application:
            VStack(alignment: .leading, spacing: 6) {
              Text("Application Path")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

              HStack {
                TextField(
                  "", text: $action.value, prompt: Text("/Applications/Safari.app")
                )
                .textFieldStyle(.roundedBorder)
                .truncationMode(.middle)
                .onChange(of: action.value) { oldValue, newValue in
                  localValues[action.type] = newValue
                }

                Button("Choose…") {
                  let panel = NSOpenPanel()
                  panel.allowedContentTypes = [.application]
                  panel.canChooseFiles = true
                  panel.allowsMultipleSelection = false
                  if panel.runModal() == .OK, let path = panel.url?.path {
                    DispatchQueue.main.async {
                      localValues[action.type] = path
                      var updatedAction = action
                      updatedAction.value = path
                      action = updatedAction
                    }
                  }
                }
                .controlSize(.small)
              }
            }

          case .folder:
            VStack(alignment: .leading, spacing: 6) {
              Text("Folder Path")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

              HStack {
                TextField("", text: $action.value, prompt: Text("~/Downloads"))
                  .textFieldStyle(.roundedBorder)
                  .truncationMode(.middle)
                  .onChange(of: action.value) { oldValue, newValue in
                    localValues[action.type] = newValue
                  }

                Button("Choose…") {
                  let panel = NSOpenPanel()
                  panel.canChooseDirectories = true
                  panel.canChooseFiles = false
                  panel.allowsMultipleSelection = false
                  if panel.runModal() == .OK, let path = panel.url?.path {
                    DispatchQueue.main.async {
                      localValues[action.type] = path
                      var updatedAction = action
                      updatedAction.value = path
                      action = updatedAction
                    }
                  }
                }
                .controlSize(.small)
              }
            }

          case .url:
            VStack(alignment: .leading, spacing: 6) {
              Text("URL")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

              TextField("", text: $action.value, prompt: Text("https://apple.com"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: action.value) { oldValue, newValue in
                  localValues[action.type] = newValue
                }
            }

          case .command:
            VStack(alignment: .leading, spacing: 6) {
              Text("Shell Command")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

              TextField(
                "", text: $action.value,
                prompt: Text("for i in {1..3}; do say \"hello $i\"; done")
              )
              .textFieldStyle(.roundedBorder)
              .onChange(of: action.value) { oldValue, newValue in
                localValues[action.type] = newValue
              }
            }

          case .group:
            EmptyView()
          }
        }
      }
      .padding(.horizontal, 4)

      Spacer()
    }
    .onAppear {
      isLabelFocused = true
      // Initialize local values with current action value
      localValues[action.type] = action.value
    }
    .sheet(isPresented: $iconPickerPresented) {
      SymbolPicker(
        symbol: Binding(
          get: { action.iconPath },
          set: { newPath in
            var updatedAction = action
            updatedAction.iconPath = newPath
            action = updatedAction
          }
        ))
    }
  }
}

struct SelectAllTextField: NSViewRepresentable {
  @Binding var text: String
  var isFocused: FocusState<Bool>.Binding
  var placeholder: String = ""

  func makeNSView(context: Context) -> NSTextField {
    let textField = NSTextField(string: text)
    textField.delegate = context.coordinator
    textField.font = .systemFont(ofSize: 18, weight: .semibold)
    textField.placeholderString = placeholder
    textField.isBordered = true
    textField.backgroundColor = .textBackgroundColor
    textField.drawsBackground = true
    textField.layer?.cornerRadius = 5.0
    textField.layer?.borderWidth = 1.0
    textField.layer?.borderColor = NSColor.separatorColor.cgColor
    return textField
  }

  func updateNSView(_ nsView: NSTextField, context: Context) {
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
    if nsView.placeholderString != placeholder {
      nsView.placeholderString = placeholder
    }
    if isFocused.wrappedValue && !context.coordinator.isFirstResponder {
      DispatchQueue.main.async {
        nsView.window?.makeFirstResponder(nsView)
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, isFocused: isFocused)
  }

  class Coordinator: NSObject, NSTextFieldDelegate {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var isFirstResponder: Bool = false

    init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
      _text = text
      self.isFocused = isFocused
    }

    func controlTextDidChange(_ obj: Notification) {
      guard let textField = obj.object as? NSTextField else { return }
      self.text = textField.stringValue
    }

    func controlDidBeginEditing(_ obj: Notification) {
      guard let textField = obj.object as? NSTextField else { return }
      isFirstResponder = true
      textField.selectAll(nil)
    }

    func controlDidEndEditing(_ obj: Notification) {
      isFirstResponder = false
      isFocused.wrappedValue = false
    }
  }
}

struct LabelTextField: View {
  @Binding var text: String
  let prompt: String
  let isLabelFocused: FocusState<Bool>.Binding
  @Binding var labelFieldAnchor: NSView?
  @State private var isHovered = false

  var body: some View {
    TextField("", text: $text, prompt: Text(prompt))
      .frame(width: 189, height: 24)
      .padding(.leading, 8)
      .textFieldStyle(.plain)
      .background(
        RoundedRectangle(cornerRadius: 5)
          .fill(Color(.controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(
            isHovered ? Color.primary.opacity(0.3) : Color.primary.opacity(0.15),
            lineWidth: 0.5
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .focused(isLabelFocused)
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.15)) {
          isHovered = hovering
        }
      }
  }
}

struct TypeButton: View {
  let type: Type
  let icon: String
  let label: String
  let isSelected: Bool
  let onTap: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .frame(width: 24, height: 24)

        Text(label)
          .font(.caption)
          .lineLimit(1)
      }
      .frame(width: 70, height: 50)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Color.gray.opacity(0.3) : Color.clear)
      )
      .foregroundColor(foregroundColor)
      .opacity(isSelected ? 1.0 : 0.6)
    }
    .buttonStyle(PlainButtonStyle())
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
  }

  private var foregroundColor: Color {
    if isSelected {
      return Color.primary
    } else {
      return Color.primary
    }
  }
}

extension Binding where Value == String? {
  func _orEmpty() -> Binding<String> {
    return Binding<String>(
      get: {
        return self.wrappedValue ?? ""
      },
      set: {
        self.wrappedValue = $0.isEmpty ? nil : $0
      }
    )
  }
}

// Custom button style for segmented control appearance
struct SegmentedButtonStyle: ButtonStyle {
  enum Position {
    case first, middle, last, only
  }

  let position: Position
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13))
      .frame(height: 24)
      .frame(minWidth: 60)
      .foregroundColor(.primary)
      .contentShape(Rectangle())
      .background {
        switch position {
        case .first:
          UnevenRoundedRectangle(
            topLeadingRadius: 6,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
          )
          .fill(backgroundColor(isPressed: configuration.isPressed))
        case .middle:
          Rectangle()
            .fill(backgroundColor(isPressed: configuration.isPressed))
        case .last:
          UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 6,
            topTrailingRadius: 6
          )
          .fill(backgroundColor(isPressed: configuration.isPressed))
        case .only:
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(backgroundColor(isPressed: configuration.isPressed))
        }
      }
      .overlay {
        switch position {
        case .first:
          UnevenRoundedRectangle(
            topLeadingRadius: 6,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
          )
          .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
        case .middle:
          Rectangle()
            .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
        case .last:
          UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 6,
            topTrailingRadius: 6
          )
          .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
        case .only:
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
        }
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .onHover { hovering in
        isHovered = hovering
      }
  }

  private func backgroundColor(isPressed: Bool) -> Color {
    if isPressed {
      return Color.primary.opacity(0.35)
    } else if isHovered {
      return Color.primary.opacity(0.2)
    } else {
      return Color.primary.opacity(0.08)
    }
  }
}
