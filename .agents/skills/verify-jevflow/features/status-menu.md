# Menu-bar status menu

## Sub-features

- Option-key icon opens native status/actions menu: Open JevFlow, Dictionary…, Settings…, Quit.
- Refused take adds Insert raw; missing Accessibility/caret mark adds status.

## How to get to it (user POV)

Click Option mark in menu bar while idle; choose named action. While a live card is up, click icon to cancel instead.

## Driving it with verify-jevflow

Read `Sources/Kept/DesktopWindow.swift` `menuWillOpen`; snapshots cover destination windows. Human captures the native menu and confirms actions navigate. For Insert raw first produce a refused sparse take and check actual field.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

The menu itself is not in SwiftUI snapshots. It is not a history list. Never Quit someone else's instance just for cleanup.
