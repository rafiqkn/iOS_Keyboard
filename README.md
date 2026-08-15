# KnKeys for iOS

A native, offline custom iOS keyboard with a lightweight QWERTY layout and emoji mode. It inserts Unicode text without requesting Full Access.

## Features

- Standard QWERTY layout with a permanent number row
- Home-row left-swipe deletion with configurable character and word thresholds
- Shift, Caps Lock, delete repeat, adaptive return, and double-space period
- Emoji mode with nine categories and a scrollable grid
- Emoji insertion through `textDocumentProxy`
- Globe, space, delete, and return keys
- Light and dark keyboard appearances
- Adaptive iPhone and iPad layouts
- SwiftUI host app with setup instructions and a test field
- No network access, analytics, or third-party dependencies

## Requirements

- Xcode 16 or later
- iOS 16.0 or later
- An Apple Development Team for installation on a physical device

## Run

1. Open `EmojiKeyboard.xcodeproj` in Xcode.
2. Select the `EmojiKeyboard` project and choose your Development Team for both targets.
3. Confirm that the extension bundle identifier remains a child of the app identifier:
   - App: `com.rafiqkn.KnKeys`
   - Extension: `com.rafiqkn.KnKeys.KeyboardExtension`
4. Select the `EmojiKeyboard` scheme and run it on an iPhone, iPad, or simulator.
5. Open Settings and go to **General > Keyboard > Keyboards > Add New Keyboard**.
6. Choose **KnKeys**.
7. Open a text field and use the globe key to switch to KnKeys.
8. Use the face button to open emoji mode and the keyboard button to return to QWERTY.

Full Access is not required. The extension inserts local Unicode text and does not use the network or pasteboard.

## Project Structure

- `EmojiKeyboard/`: SwiftUI host app
- `EmojiKeyboardExtension/KeyboardViewController.swift`: keyboard coordinator and input behavior
- `EmojiKeyboardExtension/KeyboardModels.swift`: keyboard state and actions
- `EmojiKeyboardExtension/KeyboardLayout.swift`: data-driven QWERTY, number, and symbol rows
- `EmojiKeyboardExtension/QwertyKeyboardView.swift`: responsive QWERTY view
- `EmojiKeyboardExtension/GestureDeletion.swift`: home-row gesture recognition and Unicode-aware deletion planning
- `EmojiKeyboardExtension/EmojiKeyboardView.swift`: existing emoji grid view
- `EmojiKeyboardExtension/EmojiCatalog.swift`: categorized emoji data
- `EmojiKeyboardExtension/EmojiCell.swift`: reusable emoji grid cell
- `EmojiKeyboardExtension/Info.plist`: keyboard extension configuration

## Command-Line Build

If `xcode-select` points to Command Line Tools, either select Xcode globally or provide `DEVELOPER_DIR` for one command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project EmojiKeyboard.xcodeproj \
  -scheme EmojiKeyboard \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```
