import SwiftUI
import UIKit

@MainActor
final class ThemeEditorModel: ObservableObject {
    @Published var selection: ThemeSelection
    @Published var theme: KeyboardTheme
    @Published var deletionFeedbackAnimation: Bool
    @Published var keyPopupEnabled: Bool
    @Published var keystrokeSoundMode: KeystrokeSoundMode
    @Published var didSave = false

    private let store: ThemeStore

    init(store: ThemeStore = ThemeStore()) {
        self.store = store
        selection = store.loadSelection()
        theme = store.loadCustomTheme()
        let interactionSettings = store.loadInteractionSettings()
        deletionFeedbackAnimation = interactionSettings.deletionFeedbackAnimation
        keyPopupEnabled = interactionSettings.keyPopupEnabled
        keystrokeSoundMode = interactionSettings.keystrokeSoundMode
    }

    func save() {
        theme = KeyboardThemeValidator.validated(theme)
        store.save(
            selection: selection,
            customTheme: theme,
            deletionFeedbackAnimation: deletionFeedbackAnimation,
            keyPopupEnabled: keyPopupEnabled,
            keystrokeSoundMode: keystrokeSoundMode
        )
        didSave = true
    }

    func reset() {
        theme = .light
        selection = .custom
        didSave = false
    }

    var previewTheme: KeyboardTheme {
        switch selection {
        case .automatic, .light: return .light
        case .dark: return .dark
        case .custom: return KeyboardThemeValidator.validated(theme)
        }
    }
}

struct ThemeSettingsView: View {
    @StateObject private var model = ThemeEditorModel()

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $model.selection) {
                    ForEach(ThemeSelection.allCases) { selection in
                        Text(selection.title).tag(selection)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Preview") {
                KeyboardThemePreview(theme: model.previewTheme)
                    .frame(height: 190)
                    .listRowInsets(EdgeInsets())
            }

            Section("Colors") {
                themeColorPicker("Keys", color: binding(\.keyBackground))
                themeColorPicker("Keyboard", color: binding(\.keyboardBackground))
                themeColorPicker("Text", color: binding(\.textColor))
                themeColorPicker("Function keys", color: binding(\.functionKeyBackground))
                themeColorPicker("Return and Shift", color: binding(\.accentKeyBackground))
                themeColorPicker("Suggestion bar", color: binding(\.suggestionBarColor))
            }
            .disabled(model.selection != .custom)

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Corner radius")
                        Spacer()
                        Text("\(Int(model.theme.keyCornerRadius)) pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.theme.keyCornerRadius, in: 0...12, step: 1)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Key height")
                        Text("\(Int(model.theme.keyHeight)) pt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    Button {
                        adjustKeyHeight(by: -2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.theme.keyHeight <= 34)
                    .accessibilityLabel("Decrease key height")

                    Button {
                        adjustKeyHeight(by: 2)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.theme.keyHeight >= 56)
                    .accessibilityLabel("Increase key height")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font size")
                        Spacer()
                        Text("\(Int(model.theme.fontSize)) pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.theme.fontSize, in: 16...28, step: 1)
                }
            } header: {
                Text("Key Shape")
            } footer: {
                Text("Key height is bounded automatically in landscape and on smaller screens to keep the keyboard usable.")
            }
            .disabled(model.selection != .custom)

            Section {
                Toggle("Row deletion animation", isOn: $model.deletionFeedbackAnimation)
                Toggle("Key popups", isOn: $model.keyPopupEnabled)

                Picker("Keystroke sound", selection: $model.keystrokeSoundMode) {
                    ForEach(KeystrokeSoundMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Interaction")
            } footer: {
                Text("Visual feedback and the system keyboard click can be changed without affecting typing speed.")
            }

            Section {
                Button("Save Settings") {
                    model.save()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)

                Button("Reset Custom Theme", role: .destructive) {
                    model.reset()
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text(model.didSave ? "Saved. Reopen KnKeys from the globe menu to apply it." : "Theme settings are shared with the keyboard without Full Access.")
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.selection) { _ in model.didSave = false }
        .onChange(of: model.theme) { _ in model.didSave = false }
        .onChange(of: model.deletionFeedbackAnimation) { _ in model.didSave = false }
        .onChange(of: model.keyPopupEnabled) { _ in model.didSave = false }
        .onChange(of: model.keystrokeSoundMode) { _ in model.didSave = false }
    }

    private func adjustKeyHeight(by amount: Double) {
        model.theme.keyHeight = min(max(model.theme.keyHeight + amount, 34), 56)
    }

    private func binding(_ keyPath: WritableKeyPath<KeyboardTheme, ThemeColor>) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: model.theme[keyPath: keyPath].uiColor) },
            set: { model.theme[keyPath: keyPath] = ThemeColor(uiColor: UIColor($0)) }
        )
    }

    private func themeColorPicker(_ title: String, color: Binding<Color>) -> some View {
        ColorPicker(title, selection: color, supportsOpacity: false)
    }
}

private struct KeyboardThemePreview: View {
    let theme: KeyboardTheme

    private let rows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(theme.suggestionBarColor.color)
                .frame(height: 18)
                .overlay(alignment: .leading) {
                    Text("Suggestions")
                        .font(.caption2)
                        .foregroundStyle(theme.textColor.color)
                        .padding(.horizontal, 8)
                }

            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(rows[index], id: \.self) { key in
                        previewKey(key, function: key == "⇧" || key == "⌫")
                    }
                }
            }

            HStack(spacing: 4) {
                previewKey("123", function: true)
                previewKey("space", width: 3)
                previewKey("return", function: true, accent: true, width: 1.5)
            }
        }
        .padding(7)
        .background(theme.keyboardBackground.color)
    }

    private func previewKey(
        _ title: String,
        function: Bool = false,
        accent: Bool = false,
        width: CGFloat = 1
    ) -> some View {
        Text(title)
            .font(.system(size: min(theme.fontSize, 18)))
            .foregroundStyle(theme.textColor.color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: min(theme.keyHeight * 0.72, 40))
            .background(
                accent ? theme.accentKeyBackground.color :
                    (function ? theme.functionKeyBackground.color : theme.keyBackground.color)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius))
            .layoutPriority(Double(width))
    }
}

private extension ThemeColor {
    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color { Color(uiColor: uiColor) }
}
