//
//  KeyboardExtensions.swift
//  Sticker Mania App
//
//  Created by Connor on 4/17/25.
//


import SwiftUI
import UIKit

// MARK: - Hide Keyboard Extension

extension UIApplication {
    /// Sends the resignFirstResponder action to the shared application,
    /// effectively dismissing the keyboard for any active text input view.
    func endEditing() {
        // Use main thread to ensure UI updates happen correctly
        DispatchQueue.main.async {
            self.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Keyboard Toolbar Modifier

/// A ViewModifier that adds a custom toolbar to the keyboard with only a
/// "Done" button aligned to the right.
struct KeyboardToolbar: ViewModifier {
    /// The action to perform when the Done button is tapped.
    var onDone: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Use ToolbarItemGroup with placement .keyboard to add items to the keyboard accessory view
                ToolbarItemGroup(placement: .keyboard) {
                    // Spacer pushes the Button to the right edge
                    Spacer()

                    Button("Done") {
                        onDone()
                    }
                }
            }
    }
}

// MARK: - Keyboard Dismiss Modifiers

/// A ViewModifier that dismisses the keyboard when the modified view is tapped.
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
    }
}

/// A ViewModifier that adds a tappable clear background overlay (when enabled
/// and keyboard is potentially visible) to dismiss the keyboard on tap outside
/// the main content.
struct TapToDismissKeyboard: ViewModifier {
    var enabled: Bool = true

    func body(content: Content) -> some View {
        // Using GeometryReader ensures the tap area covers the screen
        // regardless of the parent ZStack's layout behavior.
        GeometryReader { geometry in
            ZStack {
                // Your original content
                content

                // Add the dismiss overlay conditionally
                if enabled && UIResponder.currentFirstResponder != nil {
                    Color.clear
                        // Ensure overlay covers the full geometry provided
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle()) // Make the clear color tappable
                        .onTapGesture {
                            // print("Tap outside detected, dismissing keyboard.") // Uncomment for debugging
                            UIApplication.shared.endEditing()
                        }
                        // No edgesIgnoringSafeArea needed here typically, as GeometryReader provides the context
                        // and the ZStack contains it. Applied to the Color if needed for specific layouts.
                }
            }
        }
    }
}

// MARK: - View Extension for Keyboard Helpers

extension View {
    /// Adds a gesture recognizer to dismiss the keyboard when the user swipes down
    /// on the modified view.
    /// - Returns: A view modified to dismiss the keyboard on a downward swipe.
    func dismissKeyboardOnSwipeDown() -> some View {
        return gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    // Check if the swipe is predominantly downward
                    let verticalMovement = value.translation.height
                    let horizontalMovement = value.translation.width

                    // Ensure it's mostly vertical and actually downwards
                    if verticalMovement > 0 && abs(verticalMovement) > abs(horizontalMovement) {
                        UIApplication.shared.endEditing()
                    }
                }
        )
    }

    /// Adds a tap gesture recognizer to dismiss the keyboard when the user taps
    /// directly on the modified view itself.
    /// - Returns: A view modified to dismiss the keyboard on tap.
    func dismissKeyboardOnTap() -> some View {
        return modifier(KeyboardDismissModifier())
    }

    /// Adds an overlay that allows dismissing the keyboard by tapping outside the
    /// main content area, when the keyboard is potentially visible.
    /// - Parameter enabled: A Boolean value indicating whether the dismiss behavior is active. Defaults to `true`.
    /// - Returns: A view modified to allow dismissing the keyboard by tapping outside.
    func dismissKeyboardOnTapOutside(enabled: Bool = true) -> some View {
        return modifier(TapToDismissKeyboard(enabled: enabled))
    }

    /// Adds a standard keyboard toolbar with a single "Done" button on the right
    /// that dismisses the keyboard when tapped.
    /// - Returns: A view modified to include the "Done" button keyboard toolbar.
    func addDoneButtonToKeyboard() -> some View {
        return self.modifier(KeyboardToolbar(onDone: {
            UIApplication.shared.endEditing()
        }))
    }
}

// MARK: - First Responder Tracking

extension UIResponder {
    private struct Static {
        static weak var currentFirstResponder: UIResponder?
    }

    /// Tracks the current first responder (the view actively receiving input, like a TextField).
    static var currentFirstResponder: UIResponder? {
        Static.currentFirstResponder = nil
        // Send an action to the responder chain to find the first responder
        // Ensure this runs on the main thread as it involves UI elements
        DispatchQueue.main.async {
             UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        }
        return Static.currentFirstResponder
    }

    @objc private func findFirstResponder(_ sender: Any) {
        // When this method is called, `self` is the current first responder
        Static.currentFirstResponder = self
    }
}
