=# Drag-and-Drop Refactoring Plan

This document outlines the plan to improve the drag-and-drop functionality in the configuration list view, making it more intuitive and user-friendly while preserving existing interactions.

## 1. Current State

Currently, reordering items in the list is initiated by clicking and dragging a small, dedicated handle (`☰`) located on the right side of each row. While functional, this handle can be a small target and may not be immediately obvious to all users.

## 2. User Goal

The objective is to make reordering feel more fluid and discoverable. The user suggested allowing a drag to be initiated by clicking on the folder icon (`>`), the trigger key, or the item's icon.

## 3. Analysis & Challenges

The suggested approach presents a significant UI challenge: the proposed drag targets are already interactive elements with their own distinct functions:

*   **Folder Icon (`>`):** A button that expands or collapses a group.
*   **Trigger Key:** A text field that requires a click to gain focus for editing.
*   **Item Icon:** A menu that opens to allow changing the icon.

Assigning a click-and-drag gesture to these elements directly would conflict with their primary actions, leading to a frustrating user experience. For example, a user attempting to click the key field to edit it might accidentally initiate a drag.

## 4. Proposed Solution

To achieve the goal without introducing UI conflicts, we will refactor the drag interaction with the following approach:

*   **Make the Entire Row Draggable:** The drag gesture will be attached to the entire row. This provides a much larger and more forgiving target for the user.
*   **Use the Grab Cursor for Affordance:** The mouse cursor will change to a "grab hand" when hovering over any non-interactive part of the row, clearly indicating that the row can be moved.
*   **Preserve Existing Controls:** All existing controls will retain their functionality. Users will still be able to:
    *   Click the folder icon to expand/collapse.
    *   Click the trigger key to edit it.
    *   Click the item icon to open the icon menu.
    *   Click the "Edit" button or the row background to open the property inspector sheet.
*   **Remove Redundant Handle:** The dedicated `☰` drag handle icon will be removed, as it is no longer necessary.

This solution provides the best of both worlds: a large, obvious drag target and the preservation of all existing, well-understood UI controls.

## 5. Implementation Steps

1.  **Modify `ConfigRowContainer.swift`:**
    *   The `DragGesture` is already attached here. We will ensure it applies to the entire background area of the row.
2.  **Modify `ActionOrGroupRow.swift`:**
    *   Add an `.onHover` modifier to the row's background. This will change the cursor to `NSCursor.openHand` when hovering, providing a visual cue for draggability. The logic should be smart enough not to change the cursor when hovering over an already interactive element (like a button or text field, which often set their own cursors).
    *   Ensure the existing `.onTapGesture` (which opens the property inspector) coexists peacefully with the main drag gesture. The tap should be recognized, but a small mouse movement after the click should initiate a drag.
3.  **Modify `ActionRow.swift` and `GroupRow.swift`:**
    *   Remove the `Image(systemName: "line.3.horizontal")` view and its associated modifiers from both row types.
