#if canImport(SwiftUI)
import SwiftUI

/// A small SwiftUI playground that shows how a line is split into directional runs
/// and why it may render differently than expected.
///
/// The view is optional: the analysis in `BidiLab` has no UI dependencies, so you can
/// use it in tests, CLI tools or a debug overlay.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct BidiLabView: View {
    @State private var text: String

    public init(initialText: String = "iPhone الجديد") {
        _text = State(initialValue: initialText)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bidi Lab")
                .font(.headline)

            TextField("Type a line of mixed text", text: $text)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Rendered right-to-left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Runs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(BidiLab.runs(in: text).enumerated()), id: \.offset) { _, run in
                    HStack(spacing: 8) {
                        Text(run.direction.rawValue.uppercased())
                            .font(.caption2.monospaced())
                            .foregroundStyle(color(for: run.direction))
                            .frame(width: 64, alignment: .leading)
                        Text(run.text)
                            .font(.body.monospaced())
                    }
                }
            }

            let problems = BidiLab.issues(in: text)
            if !problems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(problems.enumerated()), id: \.offset) { _, issue in
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if BidiLab.addingRTLMarks(to: text) != text {
                Button("Add RLM marks") {
                    text = BidiLab.addingRTLMarks(to: text)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func color(for direction: BidiDirection) -> Color {
        switch direction {
        case .rtl: return .green
        case .ltr: return .blue
        case .number: return .purple
        case .neutral: return .secondary
        }
    }
}
#endif
