import XCTest

@testable import BidiLab

final class BidiLabTests: XCTestCase {

    // MARK: - Classification

    func testArabicIsRTL() {
        XCTAssertEqual(BidiLab.direction(of: "م"), .rtl)
        XCTAssertEqual(BidiLab.direction(of: "ي"), .rtl)
    }

    func testHebrewIsRTL() {
        XCTAssertEqual(BidiLab.direction(of: "א"), .rtl)
    }

    func testLatinIsLTR() {
        XCTAssertEqual(BidiLab.direction(of: "A"), .ltr)
        XCTAssertEqual(BidiLab.direction(of: "é"), .ltr)
    }

    func testDigitsAreNumbers() {
        XCTAssertEqual(BidiLab.direction(of: "7"), .number)
        XCTAssertEqual(BidiLab.direction(of: "٣"), .number)
    }

    func testPunctuationIsNeutral() {
        XCTAssertEqual(BidiLab.direction(of: "!"), .neutral)
        XCTAssertEqual(BidiLab.direction(of: " "), .neutral)
    }

    func testControlCharactersAreDetected() {
        XCTAssertTrue(BidiLab.isControl("\u{200F}"))
        XCTAssertTrue(BidiLab.isControl("\u{202B}"))
        XCTAssertFalse(BidiLab.isControl("م"))
    }

    // MARK: - Runs

    func testPureArabicIsOneRun() {
        let runs = BidiLab.runs(in: "مرحبا")
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].direction, .rtl)
        XCTAssertEqual(runs[0].text, "مرحبا")
        XCTAssertEqual(runs[0].range, 0..<5)
    }

    func testMixedLineSplitsIntoTwoRuns() {
        let runs = BidiLab.runs(in: "iPhone جديد")
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].direction, .ltr)
        XCTAssertEqual(runs[0].text, "iPhone ")
        XCTAssertEqual(runs[1].direction, .rtl)
        XCTAssertEqual(runs[1].text, "جديد")
    }

    func testNeutralsJoinThePrecedingRun() {
        let runs = BidiLab.runs(in: "مرحبا iPhone")
        XCTAssertEqual(runs.map(\.direction), [.rtl, .ltr])
        XCTAssertEqual(runs[1].range, 6..<12)
    }

    func testLeadingNeutralsAdoptTheFirstStrongDirection() {
        let runs = BidiLab.runs(in: "  مرحبا")
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].direction, .rtl)
    }

    func testEmptyTextHasNoRuns() {
        XCTAssertTrue(BidiLab.runs(in: "").isEmpty)
    }

    // MARK: - Issues

    func testDetectsStrayRLM() {
        let issues = BidiLab.issues(in: "\u{200F}مرحبا")
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].kind, .strayControl)
        XCTAssertEqual(issues[0].range, 0..<1)
    }

    func testDetectsLegacyEmbeddings() {
        let issues = BidiLab.issues(in: "\u{202B}مرحبا\u{202C}")
        XCTAssertEqual(issues.count, 2)
        XCTAssertTrue(issues.allSatisfy { $0.kind == .legacyEmbedding })
    }

    func testDetectsLatinInitialLine() {
        let issues = BidiLab.issues(in: "iPhone جديد")
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].kind, .latinInitial)
        XCTAssertEqual(issues[0].range, 0..<11)
    }

    func testArabicFirstLineHasNoIssue() {
        XCTAssertTrue(BidiLab.issues(in: "جديد iPhone").isEmpty)
    }

    func testPureLatinLineHasNoIssue() {
        XCTAssertTrue(BidiLab.issues(in: "Hello world").isEmpty)
    }

    func testEachLineIsCheckedSeparately() {
        let issues = BidiLab.issues(in: "مرحبا\niPhone جديد")
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].range, 6..<17)
    }

    // MARK: - Fixes

    func testAddsRLMToMixedLine() {
        XCTAssertEqual(BidiLab.addingRTLMarks(to: "iPhone جديد"), "\u{200F}iPhone جديد")
    }

    func testLeavesArabicLineAlone() {
        XCTAssertEqual(BidiLab.addingRTLMarks(to: "مرحبا"), "مرحبا")
    }

    func testLeavesLatinLineAlone() {
        XCTAssertEqual(BidiLab.addingRTLMarks(to: "Hello"), "Hello")
    }

    func testDoesNotDoublePrefixRLM() {
        let once = BidiLab.addingRTLMarks(to: "iPhone جديد")
        XCTAssertEqual(BidiLab.addingRTLMarks(to: once), once)
    }

    func testPreservesIndentation() {
        XCTAssertEqual(
            BidiLab.addingRTLMarks(to: "  iPhone جديد"),
            "  \u{200F}iPhone جديد"
        )
    }

    func testRemovesControlCharacters() {
        XCTAssertEqual(
            BidiLab.removingControlCharacters(from: "\u{200F}مرحبا\u{200E}"),
            "مرحبا"
        )
    }

    // MARK: - Explanation

    func testExplanationMentionsRunsAndIssues() {
        let lines = BidiLab.explanation(for: "iPhone جديد")
        XCTAssertTrue(lines.contains { $0.contains("run(s)") })
        XCTAssertTrue(lines.contains { $0.contains("rtl") })
        XCTAssertTrue(lines.contains { $0.contains("RLM") })
    }

    func testExplanationForCleanTextHasNoIssues() {
        let lines = BidiLab.explanation(for: "مرحبا")
        XCTAssertFalse(lines.contains { $0.contains("invisible bidi control") })
    }
}
