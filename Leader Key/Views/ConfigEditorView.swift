import Defaults
import KeyboardShortcuts
import SwiftUI
import SymbolPicker

let generalPadding: CGFloat = 8

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
  
  func makeNSView(context: Context) -> NSView {
    let view = DragHandleView()
    view.onDragChanged = onDragChanged
    view.onDragEnded = onDragEnded
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
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
    
    override func mouseEntered(with event: NSEvent) {
      NSCursor.openHand.set()
    }
    
    override func mouseExited(with event: NSEvent) {
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
  let time: Date = Date()
  let velocity: CGSize = .zero
  let predictedEndLocation: CGPoint = .zero
  let predictedEndTranslation: CGSize = .zero
}

struct AddButtons: View {
  let onAddAction: () -> Void
  let onAddGroup: () -> Void

  var body: some View {
    HStack(spacing: generalPadding) {
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
  @Published var currentDropIndex: Int?
  @Published var currentDropPath: [Int]?
  @Published var dragOffset: CGSize = .zero
  @Published var isDragging: Bool = false
  @Published var draggedItemOffset: CGSize = .zero
  @Published var previewDropIndex: Int?
  @Published var originalArray: [ActionOrGroup] = []
  @Published var dragLocation: CGPoint = .zero
  @Published var dragStartLocation: CGPoint = .zero
  @Published var hoveredGroupPath: [Int]? // Track which group we're hovering over
  @Published var autoExpandTimer: Timer? // Timer for auto-expanding groups
}

struct GroupContentView: View {
  @Binding var group: Group
  @EnvironmentObject var userConfig: UserConfig
  @EnvironmentObject var dragState: DragState
  var isRoot: Bool = false
  var parentPath: [Int] = []
  @Binding var expandedGroups: Set<[Int]>

  var body: some View {
    LazyVStack(spacing: generalPadding) {
      ForEach(group.actions.indices, id: \.self) { index in
        let currentPath = parentPath + [index]
        let isDragged = dragState.draggedFromPath == currentPath
        let shouldShowDropZone = shouldShowDropZoneAbove(index: index)
        
        ConfigRowContainer(
          item: group.actions[index],
          index: index,
          currentPath: currentPath,
          isDragged: isDragged,
          shouldShowDropZone: shouldShowDropZone,
          group: $group,
          dragState: dragState,
          expandedGroups: $expandedGroups,
          parentPath: parentPath,
          performDrop: performDrop,
          startDrag: startDrag,
          handleGlobalDragMove: handleGlobalDragMove,
          endDrag: endDrag
        )
      }
      
      // Drop zone at the end
      if dragState.draggedItem != nil {
        DropZoneView(isActive: dragState.currentDropIndex == group.actions.count && dragState.currentDropPath == parentPath)
          .onTapGesture {
            performDrop(at: group.actions.count)
          }
      }

      AddButtons(
        onAddAction: {
          withAnimation {
            group.actions.append(
              .action(Action(key: "", type: .application, value: "")))
          }
        },
        onAddGroup: {
          withAnimation {
            group.actions.append(.group(Group(key: "", actions: [])))
          }
        }
      )
      .padding(.top, generalPadding * 0.5)
    }
  }

  private func binding(for index: Int) -> Binding<ActionOrGroup> {
    Binding(
      get: { group.actions[index] },
      set: { group.actions[index] = $0 }
    )
  }
  
  private func shouldShowDropZoneAbove(index: Int) -> Bool {
    guard let dropIndex = dragState.currentDropIndex,
          let dropPath = dragState.currentDropPath,
          dragState.draggedItem != nil else { return false }
    return dropIndex == index && dropPath == parentPath
  }
  
  
  private func startDrag(item: ActionOrGroup, fromPath: [Int]) {
    dragState.draggedItem = item
    dragState.draggedFromPath = fromPath
    dragState.isDragging = true
    dragState.draggedItemOffset = .zero
    
    // Apple guideline: Provide haptic feedback for drag start
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }
  
  private func handleDragMove(_ offset: CGSize, over path: [Int]) {
    // Update the visual offset for the dragged item
    dragState.draggedItemOffset = offset
    
    // Calculate drop position based on drag offset from NSView
    let rowHeight: CGFloat = 60
    let relativeY = offset.height
    
    if let currentIndex = path.last {
      let targetIndex: Int
      
      if relativeY > rowHeight * 0.8 {
        // Mouse moved DOWN - move item UP in list (lower index)
        targetIndex = max(currentIndex - 1, 0)
      } else if relativeY > rowHeight * 0.3 {
        // Mouse moved DOWN slightly - show drop zone above
        targetIndex = max(currentIndex, 0)
      } else if relativeY < -rowHeight * 1.2 {
        // Mouse moved UP very far - move item to very end of list
        targetIndex = group.actions.count
      } else if relativeY < -rowHeight * 0.8 {
        // Mouse moved UP far - move item DOWN in list (higher index)
        targetIndex = min(currentIndex + 2, group.actions.count)
      } else if relativeY < -rowHeight * 0.3 {
        // Mouse moved UP slightly - show drop zone below
        targetIndex = min(currentIndex + 1, group.actions.count)
      } else {
        dragState.currentDropIndex = nil
        dragState.currentDropPath = nil
        return
      }
      
      dragState.currentDropIndex = targetIndex
      dragState.currentDropPath = parentPath
    }
  }
  
  private func handleGlobalDragMove(_ value: DragGesture.Value, startingFrom path: [Int]) {
    // Safety check: ensure we have valid drag state
    guard dragState.draggedItem != nil,
          !group.actions.isEmpty else { return }
    
    // Update the visual offset for the dragged item
    dragState.draggedItemOffset = value.translation
    dragState.dragLocation = value.location
    
    // Calculate drop position based on global drag position
    let rowHeight: CGFloat = 60
    let translation = value.translation
    let relativeY = translation.height
    
    if let currentIndex = path.last,
       currentIndex >= 0,
       currentIndex < group.actions.count {
      let targetIndex: Int
      
      // Calculate how many rows we've moved
      let rowsMoved = Int(relativeY / rowHeight)
      
      if rowsMoved > 0 {
        // Moving DOWN - increase index
        targetIndex = min(currentIndex + rowsMoved + 1, group.actions.count)
      } else if rowsMoved < 0 {
        // Moving UP - decrease index
        targetIndex = max(currentIndex + rowsMoved, 0)
      } else {
        // Small movement - check if we should show adjacent drop zone
        if relativeY > rowHeight * 0.3 {
          targetIndex = min(currentIndex + 1, group.actions.count)
        } else if relativeY < -rowHeight * 0.3 {
          targetIndex = currentIndex
        } else {
          // Not dragged far enough - no drop zone
          dragState.currentDropIndex = nil
          dragState.currentDropPath = nil
          dragState.previewDropIndex = nil
          return
        }
      }
      
      dragState.currentDropIndex = targetIndex
      dragState.currentDropPath = parentPath
      
      // Store the preview drop index for visual feedback only
      // We'll perform the actual reorder on drag end to avoid crashes
      dragState.previewDropIndex = targetIndex
    }
  }
  
  private func performLiveReorder(to targetIndex: Int, from currentIndex: Int) {
    guard targetIndex != currentIndex,
          targetIndex >= 0,
          targetIndex <= group.actions.count,
          currentIndex >= 0,
          currentIndex < group.actions.count,
          !group.actions.isEmpty else { return }
    
    // Apple guideline: Provide subtle haptic feedback for reordering
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    
    // Apple guideline: Smooth, natural animation for reordering
    withAnimation(Animation.spring(response: 0.35, dampingFraction: 0.8)) {
      let item = group.actions.remove(at: currentIndex)
      let insertIndex = targetIndex > currentIndex ? targetIndex - 1 : targetIndex
      let safeInsertIndex = max(0, min(insertIndex, group.actions.count))
      group.actions.insert(item, at: safeInsertIndex)
      
      // Update the dragged path to reflect the new position
      if let draggedFromPath = dragState.draggedFromPath {
        var newPath = draggedFromPath
        if newPath.count > 0 {
          newPath[newPath.count - 1] = safeInsertIndex
          dragState.draggedFromPath = newPath
        }
      }
    }
  }
  
  private func endDrag() {
    // Perform the final drop operation
    performFinalDrop()
    
    // Reset drag state
    dragState.autoExpandTimer?.invalidate()
    dragState.autoExpandTimer = nil
    dragState.draggedItem = nil
    dragState.draggedFromPath = nil
    dragState.currentDropIndex = nil
    dragState.currentDropPath = nil
    dragState.dragOffset = .zero
    dragState.isDragging = false
    dragState.draggedItemOffset = .zero
    dragState.previewDropIndex = nil
    dragState.originalArray = []
    dragState.hoveredGroupPath = nil
  }
  
  private func performFinalDrop() {
    guard let draggedItem = dragState.draggedItem,
          let fromPath = dragState.draggedFromPath,
          let dropIndex = dragState.currentDropIndex,
          let dropPath = dragState.currentDropPath else { return }
    
    // Remove item from original location
    removeItemFromPath(fromPath)
    
    // Insert item at new location
    insertItemAtPath(draggedItem, path: dropPath, index: dropIndex)
    
    // Provide haptic feedback for completion
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }
  
  private func removeItemFromPath(_ path: [Int]) {
    guard !path.isEmpty else { return }
    
    if path.count == 1 {
      // Remove from current group
      let index = path[0]
      if index < group.actions.count {
        group.actions.remove(at: index)
      }
    } else {
      // Remove from nested group - would need to traverse hierarchy
      // For now, handle simple case
    }
  }
  
  private func insertItemAtPath(_ item: ActionOrGroup, path: [Int], index: Int) {
    if path == parentPath {
      // Insert into current group
      let safeIndex = max(0, min(index, group.actions.count))
      group.actions.insert(item, at: safeIndex)
    } else {
      // Insert into different group - would need to traverse hierarchy
      // For now, handle simple case
    }
  }
  
  private func handleGroupHover(_ groupPath: [Int]) {
    // Check if we're hovering over a different group
    if dragState.hoveredGroupPath != groupPath {
      dragState.hoveredGroupPath = groupPath
      
      // Cancel previous timer
      dragState.autoExpandTimer?.invalidate()
      
      // Start new timer for auto-expansion
      dragState.autoExpandTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
        DispatchQueue.main.async {
          // Auto-expand the group
          if !expandedGroups.contains(groupPath) {
            withAnimation(.easeOut(duration: 0.2)) {
              expandedGroups.insert(groupPath)
            }
            // Provide haptic feedback for expansion
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
          }
        }
      }
    }
  }
  
  private func performDrop(at index: Int) {
    guard let draggedItem = dragState.draggedItem,
          let fromPath = dragState.draggedFromPath else { return }
    
    withAnimation(.easeInOut(duration: 0.3)) {
      // Remove from original position
      if let fromIndex = fromPath.last, fromPath.dropLast() == parentPath {
        group.actions.remove(at: fromIndex)
        let adjustedIndex = fromIndex < index ? index - 1 : index
        group.actions.insert(draggedItem, at: adjustedIndex)
      } else {
        // Cross-hierarchy move - just insert at target position
        group.actions.insert(draggedItem, at: index)
      }
    }
  }
}

struct ConfigRowContainer: View {
  let item: ActionOrGroup
  let index: Int
  let currentPath: [Int]
  let isDragged: Bool
  let shouldShowDropZone: Bool
  @Binding var group: Group
  @ObservedObject var dragState: DragState
  @Binding var expandedGroups: Set<[Int]>
  let parentPath: [Int]
  let performDrop: (Int) -> Void
  let startDrag: (ActionOrGroup, [Int]) -> Void
  let handleGlobalDragMove: (DragGesture.Value, [Int]) -> Void
  let endDrag: () -> Void
  
  var body: some View {
    VStack(spacing: 0) {
      // Drop zone above this item
      if shouldShowDropZone {
        DropZoneView(isActive: dragState.currentDropIndex == index && dragState.currentDropPath == parentPath)
          .onTapGesture {
            if let draggedItem = dragState.draggedItem {
              performDrop(index)
            }
          }
      }
      
      // The actual row - dim when being dragged
      if index < group.actions.count {
        ActionOrGroupRow(
          item: Binding(
            get: { 
              guard index < group.actions.count else { return item }
              return group.actions[index] 
            },
            set: { newValue in
              guard index < group.actions.count else { return }
              group.actions[index] = newValue 
            }
          ),
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
      } else {
        // Invisible placeholder to maintain spacing
        Rectangle()
          .fill(Color.clear)
          .frame(height: 0)
      }
    }
    .gesture(
      DragGesture(minimumDistance: 10, coordinateSpace: .global)
        .onChanged { value in
          // Safety check: ensure we have a valid item and index
          guard index < group.actions.count else { return }
          
          if dragState.draggedFromPath == nil {
            // Apple guideline: Immediate visual feedback
            withAnimation(Animation.easeOut(duration: 0.15)) {
              dragState.dragStartLocation = value.location
              startDrag(item, currentPath)
            }
            NSCursor.closedHand.set()
          }
          if dragState.draggedFromPath == currentPath {
            handleGlobalDragMove(value, currentPath)
          }
        }
        .onEnded { value in
          if dragState.draggedFromPath == currentPath {
            // Apple guideline: Smooth completion animation
            withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.8)) {
              endDrag()
            }
          }
          NSCursor.arrow.set()
        }
    )
  }
}

struct DropZoneView: View {
  let isActive: Bool
  
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
          Image(systemName: iconPath.hasPrefix("SF:") ? String(iconPath.dropFirst(3)) : "folder.fill")
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

struct ConfigEditorView: View {
  @Binding var group: Group
  @EnvironmentObject var userConfig: UserConfig
  var isRoot: Bool = true
  @Binding var expandedGroups: Set<[Int]>
  @StateObject private var dragState = DragState()

  var body: some View {
    ScrollView {
      GroupContentView(
        group: $group, isRoot: isRoot, parentPath: [], expandedGroups: $expandedGroups
      )
      .environmentObject(dragState)
      .padding(
        EdgeInsets(
          top: generalPadding, leading: generalPadding,
          bottom: generalPadding, trailing: 0))
    }
    .overlay(
      GeometryReader { geometry in
        // Floating dragged item - shown at root level so it's always visible
        if let draggedItem = dragState.draggedItem,
           dragState.isDragging,
           dragState.dragLocation != .zero {
          
          FloatingDraggedRow(
            item: draggedItem,
            dragState: dragState,
            userConfig: userConfig,
            expandedGroups: $expandedGroups
          )
          .position(
            x: dragState.dragStartLocation.x - geometry.frame(in: .global).minX + 300, // Shift right so left edge is near cursor
            y: dragState.dragLocation.y - geometry.frame(in: .global).minY
          )
          .zIndex(1000)
          .allowsHitTesting(false)
        }
      }
    )
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

  var body: some View {
    switch item {
    case .action:
      ActionRow(
        action: Binding(
          get: {
            if case .action(let action) = item { return action }
            fatalError("Unexpected state")
          },
          set: { newAction in
            item = .action(newAction)
          }
        ),
        path: path,
        onDelete: onDelete,
        onDuplicate: onDuplicate,
        dragState: dragState
      )
    case .group:
      GroupRow(
        group: Binding(
          get: {
            if case .group(let group) = item { return group }
            fatalError("Unexpected state")
          },
          set: { newGroup in
            item = .group(newGroup)
          }
        ),
        path: path,
        expandedGroups: $expandedGroups,
        onDelete: onDelete,
        onDuplicate: onDuplicate,
        dragState: dragState
      )
    }
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
  let onDelete: () -> Void
  let onDuplicate: () -> Void
  @ObservedObject var dragState: DragState
  @FocusState private var isKeyFocused: Bool
  @EnvironmentObject var userConfig: UserConfig

  var body: some View {
    HStack(spacing: generalPadding) {
      Image(systemName: "line.3.horizontal")
        .foregroundColor(.secondary)
        .font(.caption)
        .padding(.trailing, generalPadding / 2)
        .onHover { hovering in
          if hovering {
            NSCursor.openHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
      
      KeyButton(
        text: Binding(
          get: { action.key ?? "" },
          set: { action.key = $0 }
        ), placeholder: "Key", validationError: validationErrorForKey,
        onKeyChanged: { _, _ in userConfig.finishEditingKey() }
      )

      Picker("Type", selection: $action.type) {
        Text("Application").tag(Type.application)
        Text("URL").tag(Type.url)
        Text("Command").tag(Type.command)
        Text("Folder").tag(Type.folder)
      }
      .frame(minWidth: 100, maxWidth: 120)
      .labelsHidden()

      IconPickerMenu(
        item: Binding(
          get: { .action(action) },
          set: { newItem in
            if case .action(let newAction) = newItem {
              action = newAction
            }
          }
        ))

      switch action.type {
      case .application:
        Button("Choose…") {
          let panel = NSOpenPanel()
          panel.allowedContentTypes = [.applicationBundle, .application]
          panel.canChooseFiles = true
          panel.canChooseDirectories = true
          panel.allowsMultipleSelection = false
          panel.directoryURL = URL(fileURLWithPath: "/Applications")

          if panel.runModal() == .OK {
            action.value = panel.url?.path ?? ""
          }
        }
        Text(action.value).truncationMode(.middle).lineLimit(1)
      case .folder:
        Button("Choose…") {
          let panel = NSOpenPanel()
          panel.allowsMultipleSelection = false
          panel.canChooseDirectories = true
          panel.canChooseFiles = false
          panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

          if panel.runModal() == .OK {
            action.value = panel.url?.path ?? ""
          }
        }
        Text(action.value).truncationMode(.middle).lineLimit(1)
      default:
        TextField("Value", text: $action.value)
      }

      Spacer()

      TextField(action.bestGuessDisplayName, text: $action.label ?? "").frame(
        width: 120
      )
      .padding(.trailing, generalPadding)

      Button(role: .none, action: onDuplicate) {
        Image(systemName: "document.on.document")
      }
      .buttonStyle(.plain)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
      }
      .buttonStyle(.plain)
      .padding(.trailing, generalPadding)
    }
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
  @FocusState private var isKeyFocused: Bool
  let onDelete: () -> Void
  let onDuplicate: () -> Void
  @ObservedObject var dragState: DragState
  @EnvironmentObject var userConfig: UserConfig

  private var isExpanded: Bool {
    expandedGroups.contains(path)
  }

  private func toggleExpanded() {
    if isExpanded {
      expandedGroups.remove(path)
    } else {
      expandedGroups.insert(path)
    }
  }

  var body: some View {
    LazyVStack(spacing: generalPadding) {
      HStack(spacing: generalPadding) {
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.secondary)
          .font(.caption)
          .padding(.trailing, generalPadding / 2)
          .onHover { hovering in
            if hovering {
              NSCursor.openHand.set()
            } else {
              NSCursor.arrow.set()
            }
          }
        
        KeyButton(
          text: Binding(
            get: { group.key ?? "" },
            set: { group.key = $0 }
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

        IconPickerMenu(
          item: Binding(
            get: { .group(group) },
            set: { newItem in
              if case .group(let newGroup) = newItem {
                group = newGroup
              }
            }
          ))

        Button(
          role: .none,
          action: {
            withAnimation(.easeOut(duration: 0.1)) {
              toggleExpanded()
            }

          }
        ) {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .padding(.horizontal, -3)
        }.buttonStyle(.bordered)

        if path.count == 1 && group.key != "", let key = group.key {
          KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name("group-\(key)")) { shortcut in
            if shortcut != nil {
              Defaults[.groupShortcuts].insert(key)
            } else {
              Defaults[.groupShortcuts].remove(key)
            }

            (NSApplication.shared.delegate as! AppDelegate).registerGlobalShortcuts()
          }
        }

        Spacer(minLength: 0)

        TextField("Label", text: $group.label ?? "").frame(width: 120)
          .padding(.trailing, generalPadding)

        Button(role: .none, action: onDuplicate) {
          Image(systemName: "document.on.document")
        }
        .buttonStyle(.plain)

        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
        .padding(.trailing, generalPadding)
      }
      .background(
        Rectangle()
          .fill(Color.clear)
          .onHover { hovering in
            if hovering && dragState.isDragging {
              handleGroupHover()
            }
          }
      )

      if isExpanded {
        HStack(spacing: 0) {
          Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1)
            .padding(.leading, generalPadding)
            .padding(.trailing, generalPadding / 3)

          GroupContentView(group: $group, parentPath: path, expandedGroups: $expandedGroups)
            .padding(.leading, generalPadding)
        }
      } else if dragState.isDragging {
        // Show drop zone for collapsed groups when dragging
        HStack(spacing: 0) {
          Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 1)
            .padding(.leading, generalPadding)
            .padding(.trailing, generalPadding / 3)
          
          DropZoneView(isActive: dragState.currentDropPath == path && dragState.currentDropIndex == 0)
            .padding(.leading, generalPadding)
            .frame(height: 20)
            .onTapGesture {
              if let draggedItem = dragState.draggedItem {
                // Insert into group at position 0
                dragState.currentDropPath = path
                dragState.currentDropIndex = 0
              }
            }
        }
      }
    }
    .padding(.horizontal, 0)
  }
  
  private func handleGroupHover() {
    // Auto-expand group when dragging over it
    if !isExpanded {
      dragState.hoveredGroupPath = path
      
      // Cancel previous timer
      dragState.autoExpandTimer?.invalidate()
      
      // Start new timer for auto-expansion
      dragState.autoExpandTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
        DispatchQueue.main.async {
          withAnimation(.easeOut(duration: 0.2)) {
            expandedGroups.insert(path)
          }
          // Provide haptic feedback for expansion
          NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
      }
    }
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
      .action(
        Action(key: "a", type: .command, value: "ls")
      ),
      .action(
        Action(key: "c", type: .url, value: "raycast://confetti")
      ),
      .action(
        Action(key: "g", type: .url, value: "https://google.com")
      ),

      // Level 1 group with actions
      .group(
        Group(
          key: "b",
          actions: [
            .action(
              Action(
                key: "c", type: .application,
                value: "/Applications/Google Chrome.app")),
            .action(
              Action(
                key: "s", type: .application, value: "/Applications/Safari.app")
            ),
          ])),

      // Level 1 group with subgroups
      .group(
        Group(
          key: "r",
          actions: [
            .action(
              Action(
                key: "e", type: .url,
                value:
                  "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
              )),
            .group(
              Group(
                key: "w",
                actions: [
                  .action(
                    Action(
                      key: "f", type: .url,
                      value: "raycast://window-management/maximize")),
                  .action(
                    Action(
                      key: "h", type: .url,
                      value: "raycast://window-management/left-half")),
                ])),
          ])),
    ])

  let userConfig = UserConfig()

  return ConfigEditorView(group: .constant(group), expandedGroups: .constant(Set<[Int]>()))
    .frame(width: 720, height: 500)
    .environmentObject(userConfig)
}
