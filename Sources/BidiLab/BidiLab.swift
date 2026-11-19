/// A small, dependency-free bidi inspector for Arabic and Hebrew text.
///
/// This is intentionally *not* a full implementation of the Unicode Bidirectional
/// Algorithm. It answers the questions that actually come up while shipping an Arabic
/// UI:
///
/// * which characters are strong RTL, strong LTR, numbers or neutral?
/// * where do the directional runs start and end?
/// * why does a line render differently than expected (invisible controls, a Latin
///   first word flipping the whole paragraph, legacy embeddings)?
/// * what is the minimal fix (prefix an RLM)?
public enum BidiDirection: String, Sendable, CaseIterable {
    case ltr
    case rtl
    case number
    case neutral
}

/// A maximal run of characters that share a resolved direction.
public struct BidiRun: Equatable, Sendable {
    public let direction: BidiDirection
    public let text: String
    /// Character offsets, not UTF-8 or UTF-16 offsets.
    public let range: Range<Int>

    public init(direction: BidiDirection, text: String, range: Range<Int>) {
        self.direction = direction
        self.text = text
        self.range = range
    }
}

public enum BidiIssueKind: String, Sendable {
    /// LRM, RLM, ALM or a stray isolate control.
    case strayControl
    /// Legacy embeddings/overrides (LRE, RLE, PDF, LRO, RLO) — prefer LRM/RLM.
    case legacyEmbedding
    /// A line that contains Arabic but starts with a Latin strong character.
    case latinInitial
}

public struct BidiIssue: Equatable, Sendable {
    public let kind: BidiIssueKind
    public let range: Range<Int>
    public let message: String

    public init(kind: BidiIssueKind, range: Range<Int>, message: String) {
        self.kind = kind
        self.range = range
        self.message = message
    }
}

public enum BidiLab {

    public static let rlm = "\u{200F}"
    public static let lrm = "\u{200E}"
    public static let alm = "\u{061C}"

    // MARK: - Classification

    public static func isArabic(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
             0xFB50...0xFDFF, 0xFE70...0xFEFF:
            return true
        default:
            return false
        }
    }

    public static func isHebrew(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x05FF, 0xFB1D...0xFB4F:
            return true
        default:
            return false
        }
    }

    public static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x30...0x39, 0x0660...0x0669, 0x06F0...0x06F9:
            return true
        default:
            return false
        }
    }

    public static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x061C, 0x200E, 0x200F,
             0x202A...0x202E,
             0x2066...0x2069:
            return true
        default:
            return false
        }
    }

    public static func isRLM(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value == 0x200F
    }

    public static func isLRM(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value == 0x200E
    }

    public static func isLegacyEmbedding(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x202A...0x202E, 0x2066...0x2069:
            return true
        default:
            return false
        }
    }

    public static func direction(of character: Character) -> BidiDirection {
        guard let scalar = character.unicodeScalars.first else { return .neutral }
        if isControl(scalar) { return .neutral }
        if isDigit(scalar) { return .number }
        if isArabic(scalar) || isHebrew(scalar) { return .rtl }
        if character.isLetter { return .ltr }
        return .neutral
    }

    // MARK: - Runs

    /// Resolve neutrals against their surroundings, then group into runs.
    ///
    /// Neutrals take the direction of the nearest strong character, preferring the
    /// preceding one. Leading neutrals adopt the first strong direction available.
    public static func runs(in text: String) -> [BidiRun] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        let raw = characters.map { direction(of: $0) }
        var resolved = raw

        for index in raw.indices where raw[index] == .neutral {
            if let previous = resolved[..<index].last(where: { $0 != .neutral }) {
                resolved[index] = previous
            } else if let next = raw[(index + 1)...].first(where: { $0 != .neutral }) {
                resolved[index] = next
            } else {
                resolved[index] = .neutral
            }
        }

        var result: [BidiRun] = []
        var start = 0
        var current = resolved[0]

        for index in 1..<characters.count where resolved[index] != current {
            result.append(
                BidiRun(
                    direction: current,
                    text: String(characters[start..<index]),
                    range: start..<index
                )
            )
            start = index
            current = resolved[index]
        }

        result.append(
            BidiRun(
                direction: current,
                text: String(characters[start...]),
                range: start..<characters.count
            )
        )
        return result
    }

    // MARK: - Diagnostics

    public static func issues(in text: String) -> [BidiIssue] {
        var found: [BidiIssue] = []
        var offset = 0
        var atLineStart = true

        for character in text {
            if character == "\n" {
                atLineStart = true
                offset += 1
                continue
            }
            if atLineStart && (character == " " || character == "\t") {
                offset += 1
                continue
            }

            if let scalar = character.unicodeScalars.first, isControl(scalar) {
                // A leading RLM is the fix this package recommends, not a bug.
                if isRLM(scalar) && atLineStart {
                    atLineStart = false
                    offset += 1
                    continue
                }

                let code = codePointLabel(scalar.value)
                if isLegacyEmbedding(scalar) {
                    found.append(
                        BidiIssue(
                            kind: .legacyEmbedding,
                            range: offset..<(offset + 1),
                            message: "legacy bidi control \(code) at character \(offset); "
                                + "use an RLM or LRM instead of embeddings"
                        )
                    )
                } else {
                    found.append(
                        BidiIssue(
                            kind: .strayControl,
                            range: offset..<(offset + 1),
                            message: "invisible bidi control \(code) at character \(offset); "
                                + "it survives copy/paste and can scramble the line"
                        )
                    )
                }
            }
            atLineStart = false
            offset += 1
        }

        var lineStart = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let characters = Array(line)
            let lineRange = lineStart..<(lineStart + characters.count)

            if characters.contains(where: { direction(of: $0) == .rtl }),
               firstStrongDirection(in: characters) == .ltr {
                found.append(
                    BidiIssue(
                        kind: .latinInitial,
                        range: lineRange,
                        message: "line starts with Latin text but contains Arabic; the paragraph "
                            + "direction becomes LTR and punctuation moves — prefix an RLM"
                    )
                )
            }

            lineStart += characters.count + 1
        }

        return found
    }

    private static func firstStrongDirection(in characters: [Character]) -> BidiDirection? {
        for character in characters {
            if let scalar = character.unicodeScalars.first {
                // A paragraph mark is a strong hint about the intended direction.
                if isRLM(scalar) { return .rtl }
                if isLRM(scalar) { return .ltr }
            }
            let direction = direction(of: character)
            if direction == .ltr || direction == .rtl {
                return direction
            }
        }
        return nil
    }

    // MARK: - Fixes

    /// Prefix an RLM to every line that mixes Arabic with a Latin first word.
    public static func addingRTLMarks(to text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let string = String(line)
                let characters = Array(string)
                guard characters.contains(where: { direction(of: $0) == .rtl }),
                      firstStrongDirection(in: characters) == .ltr,
                      !string.hasPrefix(rlm)
                else { return string }

                let indentation = string.prefix { $0 == " " || $0 == "\t" }
                return String(indentation) + rlm + string.dropFirst(indentation.count)
            }
            .joined(separator: "\n")
    }

    /// Remove every bidi control character.
    public static func removingControlCharacters(from text: String) -> String {
        String(text.filter { character in
            guard let scalar = character.unicodeScalars.first else { return true }
            return !isControl(scalar)
        })
    }

    // MARK: - Explanation

    /// A short human readable report, useful in a debug overlay or a test failure.
    public static func explanation(for text: String) -> [String] {
        var lines: [String] = []
        let runs = runs(in: text)

        let summary = Dictionary(grouping: runs, by: { $0.direction })
            .map { direction, group in
                "\(direction.rawValue): \(group.reduce(0) { $0 + $1.text.count })"
            }
            .sorted()
            .joined(separator: ", ")
        lines.append("\(runs.count) run(s) — \(summary)")

        for run in runs where run.direction == .rtl || run.direction == .ltr {
            lines.append("\(run.direction.rawValue) [\(run.range.lowerBound)..<\(run.range.upperBound)]: \(run.text)")
        }

        lines.append(contentsOf: issues(in: text).map(\.message))
        return lines
    }
}

private func codePointLabel(_ value: UInt32) -> String {
    let hex = String(value, radix: 16, uppercase: true)
    let padded = String(repeating: "0", count: max(0, 4 - hex.count)) + hex
    return "U+\(padded)"
}
