import SwiftUI
import UIKit

struct ContentView: View {
    @State private var sampleText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Enable KnKeys") {
                    SetupRow(number: "1", title: "Open Settings", detail: "General > Keyboard > Keyboards")
                    SetupRow(number: "2", title: "Add New Keyboard", detail: "Choose KnKeys")
                    SetupRow(number: "3", title: "Switch Keyboards", detail: "Tap the globe while typing")
                }

                Section("Try It") {
                    TextField("Tap here, then select KnKeys", text: $sampleText, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Open App Settings", systemImage: "gearshape.fill")
                    }
                }

                Section("Privacy") {
                    Label("No Full Access required", systemImage: "lock.shield.fill")
                    Text("KnKeys works offline and does not collect or transmit what you type.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("KnKeys")
        }
    }
}

private struct SetupRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
