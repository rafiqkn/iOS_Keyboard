import SwiftUI
import UIKit

@MainActor
final class ThemeEditorModel: ObservableObject {
    enum SaveStatus: Equatable {
        case saved
        case saving
    }

    @Published var selection: ThemeSelection
    @Published var theme: KeyboardTheme
    @Published var deletionFeedbackAnimation: Bool
    @Published var keyPopupEnabled: Bool
    @Published var keystrokeSoundMode: KeystrokeSoundMode
    @Published private(set) var saveStatus: SaveStatus = .saved
    @Published var didSave = false

    private let store: ThemeStore
    private var pendingSaveTask: Task<Void, Never>?

    init(store: ThemeStore = ThemeStore()) {
        self.store = store
        selection = store.loadSelection()
        theme = store.loadCustomTheme()
        let interactionSettings = store.loadInteractionSettings()
        deletionFeedbackAnimation = interactionSettings.deletionFeedbackAnimation
        keyPopupEnabled = interactionSettings.keyPopupEnabled
        keystrokeSoundMode = interactionSettings.keystrokeSoundMode
    }

    func scheduleAutoSave() {
        pendingSaveTask?.cancel()
        saveStatus = .saving
        didSave = false

        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persist()
        }
    }

    func flushPendingChanges() {
        guard saveStatus == .saving else { return }
        pendingSaveTask?.cancel()
        persist()
    }

    func save() {
        pendingSaveTask?.cancel()
        persist()
    }

    private func persist() {
        let validatedTheme = KeyboardThemeValidator.validated(theme)
        store.save(
            selection: selection,
            customTheme: validatedTheme,
            deletionFeedbackAnimation: deletionFeedbackAnimation,
            keyPopupEnabled: keyPopupEnabled,
            keystrokeSoundMode: keystrokeSoundMode
        )
        saveStatus = .saved
        didSave = true
        pendingSaveTask = nil
    }

    func reset() {
        theme = .light
        selection = .custom
        didSave = false
    }

    deinit {
        pendingSaveTask?.cancel()
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

    private let presets = QuickThemePreset.all
    private let colorColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                previewSection
                modePicker
                quickThemesSection
                colorsSection
                shapeSection
                interactionSection
                resetSection
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Theme Studio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                saveStatusView
            }
        }
        .onChange(of: model.selection) { _ in model.scheduleAutoSave() }
        .onChange(of: model.theme) { _ in model.scheduleAutoSave() }
        .onChange(of: model.deletionFeedbackAnimation) { _ in model.scheduleAutoSave() }
        .onChange(of: model.keyPopupEnabled) { _ in model.scheduleAutoSave() }
        .onChange(of: model.keystrokeSoundMode) { _ in model.scheduleAutoSave() }
        .onDisappear {
            model.flushPendingChanges()
        }
    }

    private var saveStatusView: some View {
        HStack(spacing: 5) {
            if model.saveStatus == .saving {
                ProgressView()
                    .controlSize(.small)
                Text("Saving…")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.saveStatus == .saving ? "Saving theme" : "Theme saved")
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ThemeStudioHeader(
                icon: "sparkles",
                title: "Live Preview",
                detail: "Every change appears here instantly."
            )

            KeyboardThemePreview(theme: model.previewTheme)
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }

    private var modePicker: some View {
        ThemeStudioSection(icon: "circle.lefthalf.filled", title: "Theme Mode") {
            Picker("Theme", selection: $model.selection) {
                ForEach(ThemeSelection.allCases) { selection in
                    Text(selection.title).tag(selection)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Theme mode")
        }
    }

    private var quickThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ThemeStudioHeader(
                icon: "wand.and.stars",
                title: "Quick Themes",
                detail: "Start with a complete look, then make it yours."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        ThemePresetCard(
                            preset: preset,
                            isSelected: model.selection == .custom && model.theme == preset.theme
                        ) {
                            model.selection = .custom
                            model.theme = preset.theme
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var colorsSection: some View {
        ThemeStudioSection(
            icon: "paintpalette.fill",
            title: "Colors",
            detail: customDisabledDetail
        ) {
            LazyVGrid(columns: colorColumns, spacing: 10) {
                ThemeColorCard(
                    title: "Keys",
                    icon: "keyboard",
                    color: colorBinding(\.keyBackground)
                )
                ThemeColorCard(
                    title: "Keyboard",
                    icon: "rectangle.fill",
                    color: colorBinding(\.keyboardBackground)
                )
                ThemeColorCard(
                    title: "Text",
                    icon: "textformat",
                    color: colorBinding(\.textColor)
                )
                ThemeColorCard(
                    title: "Function Keys",
                    icon: "command",
                    color: colorBinding(\.functionKeyBackground)
                )
                ThemeColorCard(
                    title: "Return & Shift",
                    icon: "return",
                    color: colorBinding(\.accentKeyBackground)
                )
                ThemeColorCard(
                    title: "Suggestion Bar",
                    icon: "text.bubble.fill",
                    color: colorBinding(\.suggestionBarColor)
                )
            }
            .disabled(model.selection != .custom)
            .opacity(model.selection == .custom ? 1 : 0.55)
        }
    }

    private var shapeSection: some View {
        ThemeStudioSection(
            icon: "slider.horizontal.3",
            title: "Shape & Typography",
            detail: customDisabledDetail
        ) {
            ThemeSliderRow(
                title: "Corner Radius",
                icon: "square.roundedbottom",
                value: $model.theme.keyCornerRadius,
                range: 0...12,
                suffix: "pt"
            )

            Divider()

            HStack(spacing: 12) {
                Label("Key Height", systemImage: "arrow.up.and.down")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(Int(model.theme.keyHeight)) pt")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42)

                StudioIconButton(
                    symbol: "minus",
                    accessibilityLabel: "Decrease key height",
                    disabled: model.theme.keyHeight <= 34
                ) {
                    adjustKeyHeight(by: -2)
                }

                StudioIconButton(
                    symbol: "plus",
                    accessibilityLabel: "Increase key height",
                    prominent: true,
                    disabled: model.theme.keyHeight >= 56
                ) {
                    adjustKeyHeight(by: 2)
                }
            }

            Divider()

            ThemeSliderRow(
                title: "Font Size",
                icon: "textformat.size",
                value: $model.theme.fontSize,
                range: 16...28,
                suffix: "pt"
            )

            Text("Key height is bounded automatically in landscape and on smaller screens.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(model.selection != .custom)
        .opacity(model.selection == .custom ? 1 : 0.55)
    }

    private var interactionSection: some View {
        ThemeStudioSection(icon: "waveform", title: "Interaction") {
            ThemeToggleRow(
                title: "Row Deletion Animation",
                icon: "arrow.left.to.line",
                isOn: $model.deletionFeedbackAnimation
            )

            Divider()

            ThemeToggleRow(
                title: "Key Popups",
                icon: "rectangle.on.rectangle",
                isOn: $model.keyPopupEnabled
            )

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Keyboard Sound", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.medium))

                Picker("Keyboard Sound", selection: $model.keystrokeSoundMode) {
                    ForEach(KeystrokeSoundMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var resetSection: some View {
        VStack(spacing: 8) {
            Button("Reset to Default", role: .destructive) {
                model.reset()
            }
            .font(.subheadline.weight(.medium))

            Text("Changes save automatically and sync securely with the keyboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    private var customDisabledDetail: String? {
        model.selection == .custom ? nil : "Choose Custom or a Quick Theme to edit these controls."
    }

    private func adjustKeyHeight(by amount: Double) {
        model.theme.keyHeight = min(max(model.theme.keyHeight + amount, 34), 56)
    }

    private func colorBinding(_ keyPath: WritableKeyPath<KeyboardTheme, ThemeColor>) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: model.theme[keyPath: keyPath].uiColor) },
            set: { model.theme[keyPath: keyPath] = ThemeColor(uiColor: UIColor($0)) }
        )
    }
}

private struct QuickThemePreset: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let theme: KeyboardTheme

    static let all: [QuickThemePreset] = [
        QuickThemePreset(
            id: "neon",
            title: "Neon",
            symbol: "rainbow",
            theme: KeyboardTheme(
                keyboardBackground: ThemeColor(red: 0.03, green: 0.04, blue: 0.08),
                keyBackground: ThemeColor(red: 0.06, green: 0.16, blue: 0.20),
                functionKeyBackground: ThemeColor(red: 0.18, green: 0.07, blue: 0.28),
                accentKeyBackground: ThemeColor(red: 0.00, green: 0.78, blue: 0.82),
                textColor: ThemeColor(red: 0.88, green: 1.00, blue: 0.98),
                suggestionBarColor: ThemeColor(red: 0.12, green: 0.07, blue: 0.22),
                keyCornerRadius: 8,
                keyHeight: 46,
                fontSize: 23
            )
        ),
        QuickThemePreset(
            id: "ocean",
            title: "Ocean",
            symbol: "water.waves",
            theme: KeyboardTheme(
                keyboardBackground: ThemeColor(red: 0.04, green: 0.18, blue: 0.25),
                keyBackground: ThemeColor(red: 0.18, green: 0.47, blue: 0.58),
                functionKeyBackground: ThemeColor(red: 0.07, green: 0.31, blue: 0.42),
                accentKeyBackground: ThemeColor(red: 0.25, green: 0.73, blue: 0.78),
                textColor: ThemeColor(red: 0.96, green: 1.00, blue: 1.00),
                suggestionBarColor: ThemeColor(red: 0.06, green: 0.25, blue: 0.34),
                keyCornerRadius: 7,
                keyHeight: 44,
                fontSize: 22
            )
        ),
        QuickThemePreset(
            id: "candy",
            title: "Candy",
            symbol: "heart.fill",
            theme: KeyboardTheme(
                keyboardBackground: ThemeColor(red: 0.96, green: 0.87, blue: 0.92),
                keyBackground: ThemeColor(red: 1.00, green: 0.97, blue: 0.99),
                functionKeyBackground: ThemeColor(red: 0.83, green: 0.67, blue: 0.82),
                accentKeyBackground: ThemeColor(red: 0.94, green: 0.39, blue: 0.62),
                textColor: ThemeColor(red: 0.25, green: 0.10, blue: 0.22),
                suggestionBarColor: ThemeColor(red: 0.91, green: 0.75, blue: 0.86),
                keyCornerRadius: 10,
                keyHeight: 46,
                fontSize: 22
            )
        ),
        QuickThemePreset(
            id: "midnight",
            title: "Midnight",
            symbol: "moon.stars.fill",
            theme: KeyboardTheme(
                keyboardBackground: ThemeColor(red: 0.05, green: 0.06, blue: 0.12),
                keyBackground: ThemeColor(red: 0.14, green: 0.16, blue: 0.25),
                functionKeyBackground: ThemeColor(red: 0.09, green: 0.11, blue: 0.19),
                accentKeyBackground: ThemeColor(red: 0.34, green: 0.39, blue: 0.72),
                textColor: ThemeColor(red: 0.94, green: 0.95, blue: 1.00),
                suggestionBarColor: ThemeColor(red: 0.10, green: 0.12, blue: 0.21),
                keyCornerRadius: 6,
                keyHeight: 44,
                fontSize: 22
            )
        )
    ]
}

private struct ThemeStudioHeader: View {
    let icon: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThemeStudioSection<Content: View>: View {
    let icon: String
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemeStudioHeader(icon: icon, title: title, detail: detail)
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

private struct ThemePresetCard: View {
    let preset: QuickThemePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.title3)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 5) {
                    presetSwatch(preset.theme.keyboardBackground.color)
                    presetSwatch(preset.theme.keyBackground.color)
                    presetSwatch(preset.theme.accentKeyBackground.color)
                }

                Text(preset.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(preset.theme.textColor.color)
            .padding(12)
            .frame(width: 138, height: 112, alignment: .leading)
            .background(preset.theme.keyboardBackground.color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apply \(preset.title) theme")
    }

    private func presetSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 28, height: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
    }
}

private struct ThemeColorCard: View {
    let title: String
    let icon: String
    @Binding var color: Color

    var body: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(readableForeground)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .accessibilityLabel("\(title) color")
    }

    private var readableForeground: Color {
        Color(uiColor: UIColor(color).isLightColor ? .black : .white)
    }
}

private struct ThemeSliderRow: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(value)) \(suffix)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: 1)
        }
    }
}

private struct ThemeToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
        }
    }
}

private struct StudioIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var prominent = false
    let disabled: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if prominent {
            button
                .buttonStyle(.borderedProminent)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 34, height: 34)
        }
        .disabled(disabled)
        .accessibilityLabel(accessibilityLabel)
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
        VStack(spacing: 6) {
            HStack(spacing: 1) {
                previewSuggestion("hello")
                previewSuggestion("keyboard")
                previewSuggestion("themes")
            }
            .frame(height: 28)

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
        .padding(9)
        .background(theme.keyboardBackground.color)
    }

    private func previewSuggestion(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.textColor.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.suggestionBarColor.color)
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
            .clipShape(RoundedRectangle(cornerRadius: min(theme.keyCornerRadius, 8)))
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

private extension UIColor {
    var isLightColor: Bool {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return white > 0.58
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return true }
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58
    }
}
