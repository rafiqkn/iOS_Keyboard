# KnKeys for iOS

A native, offline custom iOS keyboard with a lightweight QWERTY layout and emoji mode. It inserts Unicode text without requesting Full Access.

## Features

- Standard QWERTY layout with a permanent number row
- Independent home-row left-swipe deletion with configurable character and word thresholds
- Optional home-row deletion feedback animation, disabled by default and controlled in the app
- Basic swipe typing with local English dictionary matching and confidence ranking
- Swipe candidate overlay for correcting the most recent gesture word
- Three local word-prediction candidates using the current word and previous-word context
- Safe partial-word replacement when a prediction is selected
- Optional key popups and system keystroke sound controls
- Theme settings with Automatic, Light, Dark, and Custom modes
- Custom key, keyboard, function-key, accent-key, text, and suggestion-bar colors
- Configurable corner radius, bounded key height, and font size
- Live theme preview in the host app
- Shift, Caps Lock, delete repeat, adaptive return, and double-space period
- Emoji mode with nine categories and a scrollable grid
- Emoji insertion through `textDocumentProxy`
- Space, delete, return, and keyboard mode keys
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

The keyboard layout does not include an internal globe key. Switch keyboards using the input-mode controls provided by iOS. Swipe typing uses a bundled common-English seed lexicon; its dictionary provider is modular so a larger licensed corpus can replace it without changing gesture or ranking code.

Full Access is not required. The extension inserts local Unicode text and does not use the network or pasteboard.

Theme and interaction settings are available from the host app under **Themes** and are shared with the keyboard through the KnKeys App Group. The suggestion-bar color styles the swipe candidate overlay.

## Project Structure

- `EmojiKeyboard/`: SwiftUI host app
- `EmojiKeyboard/ThemeSettingsView.swift`: custom theme editor and live preview
- `Shared/KeyboardTheme.swift`: shared theme model, validation, and App Group storage
- `EmojiKeyboardExtension/ThemeManager.swift`: revision-cached theme resolution
- `EmojiKeyboardExtension/KeyboardViewController.swift`: keyboard coordinator and input behavior
- `EmojiKeyboardExtension/KeyboardModels.swift`: keyboard state and actions
- `EmojiKeyboardExtension/KeyboardLayout.swift`: data-driven QWERTY, number, and symbol rows
- `EmojiKeyboardExtension/QwertyKeyboardView.swift`: responsive QWERTY view
- `EmojiKeyboardExtension/GestureDeletion.swift`: Unicode-aware deletion planning and thresholds
- `EmojiKeyboardExtension/SwipeTypingGestureRecognizer.swift`: tap, deletion, and swipe intent arbitration
- `EmojiKeyboardExtension/SwipeTypingEngine.swift`: candidate generation, geometry scoring, and ranking
- `EmojiKeyboardExtension/SwipeDictionary.swift`: indexed local dictionary provider
- `EmojiKeyboardExtension/WordPredictionModels.swift`: Unicode-aware context parsing and prediction contracts
- `EmojiKeyboardExtension/WordPredictionEngine.swift`: independent prefix and previous-word prediction engine
- `EmojiKeyboardExtension/KeyPopupPresenter.swift`: reusable key popup presentation
- `EmojiKeyboardExtension/KeyboardFeedbackManager.swift`: centralized keystroke sound policy
- `EmojiKeyboardExtension/EmojiKeyboardView.swift`: existing emoji grid view
- `EmojiKeyboardExtension/EmojiCatalog.swift`: categorized emoji data
- `EmojiKeyboardExtension/EmojiCell.swift`: reusable emoji grid cell
- `EmojiKeyboardExtension/Info.plist`: keyboard extension configuration

## Tests

Run the full unit and smoke-test suite on an iOS Simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project EmojiKeyboard.xcodeproj \
  -scheme EmojiKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

The `KnKeysTests` target covers theme validation and App Group settings migration, keyboard layouts and metrics, emoji catalog integrity, deletion planning, swipe candidate generation and ranking, word prediction context and ranking, dictionary resources, key controls, emoji rendering, popup presentation, and the height policies that prevent portrait/emoji shrinking. XCTest does not replace physical-device checks for UIKit keyboard touch arbitration, `textDocumentProxy`, system keyboard sound behavior, or iOS keyboard registration.

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
