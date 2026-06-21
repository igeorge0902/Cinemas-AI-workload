# iOS Keyboard Not Showing - Analysis

Date: 2026-05-10
Scope: login, registration, searchbar tap behavior
Status: Analysis only (no code changes)

## Executive summary

If typing still works from the computer keyboard but the iOS software keyboard does not appear, there are **two different possibilities**:

1. **Simulator / hardware keyboard setting** is hiding the on-screen keyboard.
2. **App gesture conflicts** are interfering with natural first-responder behavior.

For the current codebase, the login/registration screens mostly rely on UIKit's default text-field behavior plus a global keyboard-dismiss tap recognizer, while the search screens add extra tap gestures around the search bar containers. That means the issue is not identical on every screen.

---

## 1) Login screen

### Relevant files
- `SwiftCinemas/SwiftLoginScreen/LoginVC.swift:45-66`
- `SwiftCinemas/SwiftLoginScreen/Time.swift:30-45`
- `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard:618-705`

### What the code does
- `LoginVC.viewDidLoad()` calls `hideKeyboardWhenTappedAround()`.
- `hideKeyboardWhenTappedAround()` adds a `UITapGestureRecognizer` to the whole controller view and implements `gestureRecognizer(_:shouldReceive:)` to ignore `UIControl` touches.
- The text fields are connected in storyboard and delegate is set to the login controller.

### Likely behavior
- This setup is intended to dismiss the keyboard when tapping outside the fields.
- It should not normally prevent the text fields from becoming first responder, because the gesture recognizer excludes `UIControl` touches.

### Analysis
- If the keyboard is not appearing on login **but typing still works**, the most likely cause is **simulator hardware keyboard mode** rather than the login code itself.
- If on-device keyboard still fails to show, then the global tap recognizer is the first code path to inspect, but it is not an obvious hard blocker by itself.

---

## 2) Registration screen

### Relevant files
- `SwiftCinemas/SwiftLoginScreen/SignupVC.swift:25-40`
- `SwiftCinemas/SwiftLoginScreen/Time.swift:30-45`
- `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard:746-868`

### What the code does
- `SignupVC.viewDidLoad()` also calls `hideKeyboardWhenTappedAround()`.
- Registration fields are storyboard-backed text fields with delegate connections.

### Likely behavior
- Same pattern as login: tap outside should dismiss, but text fields should still become first responder normally.

### Analysis
- Same conclusion as login: if typing works from the computer keyboard while the software keyboard does not show, **the simulator keyboard setting is the prime suspect**.
- The code does not contain an explicit focus blocker in the registration controller.

---

## 3) Search bar screens

### Relevant files
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:61-96`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:128-133`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:246-267`
- `SwiftCinemas/SwiftLoginScreen/VenueForMoviesVC.swift:47-74`

### What the code does in `MoviesVC`
- Embeds the search bar inside a container view (`sbFrame`).
- Adds a `UITapGestureRecognizer` to the container (`focusSearchBar`).
- Calls `becomeFirstResponder()` in `viewDidAppear()` and also in `searchBarShouldBeginEditing()`.

### What the code does in `VenueForMoviesVC`
- Adds the search bar inside a container view as well.
- No strong keyboard-focus helper is visible there, but the container-based setup is similar.

### Analysis
- This is the clearest app-side source of keyboard focus confusion.
- A container tap recognizer around the search bar can compete with natural editing behavior.
- Adding `becomeFirstResponder()` in multiple places is a workaround for a touch/focus issue, not the cleanest interaction model.
- If the search bar already receives focus only via forced first responder, the tap-to-edit flow may feel inconsistent.

### Important distinction
- If the user can type but the on-screen keyboard doesn't appear, the **simulator hardware keyboard** setting can still be the root cause.
- But in the search screens, the app code also has a **real gesture/focus conflict** that should be cleaned up.

---

## 4) Admin / update screens

### Relevant files
- `SwiftCinemas/SwiftLoginScreen/AdminVC.swift:41-47`
- `SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift:37-45`

### What the code does
- Both controllers add a tap gesture directly to the root view with `UIView.endEditing`.

### Analysis
- These gestures can make field focus feel flaky if the tap target resolution isn't what you expect.
- They are less directly related to the search bar issue, but they are part of the same keyboard-dismiss pattern.

---

## Root-cause ranking

### Most likely if typing works but keyboard is invisible
1. **Simulator hardware keyboard enabled** (environmental, not app code)
2. **Search bar container gestures** in `MoviesVC` / similar search screens

### Most likely app-side issues
1. `MoviesVC` search container tap gesture + forced first responder pattern
2. Root-view keyboard-dismiss gesture used on login/registration screens
3. Root-view end-editing gestures on admin screens

---

## Why forcing first responder is not the right default fix

Forcing `becomeFirstResponder()` can make the field active, but it doesn't solve the root cause if the app is:
- intercepting taps with a gesture recognizer, or
- running in a simulator mode that hides the software keyboard.

That is why it can feel like "the user is being forced to use it" instead of the UI behaving normally.

---

## Practical recommendation

### First check the environment
- If running in iOS Simulator, verify whether the **software keyboard is hidden because hardware keyboard input is connected**.

### Then fix app interaction conflicts
- Keep login/registration fields natural and avoid extra focus forcing unless needed.
- For search bars, avoid container-level tap gestures that compete with the field.
- Prefer letting the search bar become first responder through normal UIKit behavior, and only use `becomeFirstResponder()` as a fallback.

---

## Bottom line

- **Login / registration:** no obvious hard blocker in the controller code; likely simulator keyboard setting if typing works but keyboard is hidden.
- **Search bar:** there is a real app-side gesture/focus conflict in `MoviesVC` and similar search layouts.
- **Admin screens:** root-view tap-to-dismiss can contribute to focus friction.


