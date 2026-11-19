# bidi-lab

<p align="center">
  <img src="assets/header.svg" alt="bidi-lab — see why your Arabic line renders sideways" width="100%">
</p>

<p align="center">
  <a href="https://github.com/hfip/bidi-lab/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/hfip/bidi-lab/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/swift-5.9%2B-F05138?logo=swift&logoColor=white">
  <img alt="Dependencies" src="https://img.shields.io/badge/dependencies-0-8b5cf6">
  <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-22c55e">
</p>

<p align="center">
  <b>Why does "iPhone الجديد" render with the punctuation on the wrong side?</b><br>
  A tiny Swift package that classifies characters, splits a line into directional runs,
  names the usual bidi bugs, and applies the minimal fix.
</p>

---

## The three bugs it names

| Symptom | Cause | Fix |
| --- | --- | --- |
| Line reads left-to-right even though it is Arabic | first strong character is Latin, so the paragraph direction is LTR | prefix an RLM (`U+200F`) |
| Punctuation jumps to the far end | a stray or deliberate bidi control survived copy/paste | remove it, or keep it deliberately |
| Whole string breaks after a translation tool round-trip | legacy embeddings (`RLE`, `PDF`, `RLO`) | use LRM/RLM or isolates |

```
import BidiLab

BidiLab.explanation(for: "iPhone الجديد")
// ["2 run(s) — ltr: 7, rtl: 4",
//  "ltr [0..<7]: iPhone ",
//  "rtl [7..<11]: جديد",
//  "line starts with Latin text but contains Arabic; the paragraph direction
//   becomes LTR and punctuation moves — prefix an RLM"]
```

## Install

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/hfip/bidi-lab.git", from: "0.1.0")
]
```

```swift
.target(name: "MyApp", dependencies: ["BidiLab"])
```

## Usage

```swift
import BidiLab

BidiLab.direction(of: "م")            // .rtl
BidiLab.runs(in: "iPhone جديد")       // [ltr "iPhone ", rtl "جديد"]
BidiLab.issues(in: "iPhone جديد")     // [.latinInitial]
BidiLab.addingRTLMarks(to: "iPhone جديد")   // "\u{200F}iPhone جديد"
BidiLab.removingControlCharacters(from: "\u{200F}مرحبا")  // "مرحبا"
BidiLab.explanation(for: text)        // human readable report
```

`BidiRun.range` uses **character** offsets, so it maps directly onto
`Array(string)` indexes — not UTF-8 or UTF-16 offsets.

## SwiftUI playground

```swift
import SwiftUI
import BidiLab

struct DebugView: View {
    var body: some View {
        BidiLabView(initialText: "iPhone الجديد")
    }
}
```

The view lives behind `#if canImport(SwiftUI)`, so the package still builds in Linux CI
and in server-side Swift targets.

Leading paragraph marks

A single RLM at the start of a line (after indentation) is treated as intentional, so the
output of `addingRTLMarks(to:)` never reports its own fix.

## What it is not

This is **not** a full implementation of the Unicode Bidirectional Algorithm. It does not
compute resolved levels (UBA rules W1–N2), and it should not be used to render text.
It classifies characters, groups them into practical runs and detects the mistakes that
show up in real apps. For the authoritative rules, see
[UAX #9](https://www.unicode.org/reports/tr9/).

## Related

- [ArabicPlural](https://github.com/hfip/ArabicPlural) — Arabic's six CLDR plural forms.
- [rtl-lint](https://github.com/hfip/rtl-lint) — catch left/right layout assumptions in
  Swift and storyboards.
- [xcstrings-audit](https://github.com/hfip/xcstrings-audit) — coverage and placeholder
  checks for String Catalogs.

## بالعربي

<div dir="rtl" align="right">

ليش الجملة `iPhone الجديد` تطلع بالمقلوب أو النقطة في الجهة الغلط؟

السبب أن أول حرف قوي في السطر لاتيني، فيصير اتجاه الفقرة LTR، والباقي يتصرف على هذا
الأساس. الحل حرف RLM واحد (`U+200F`) في بداية السطر.

هذي الحزمة الصغيرة:

- تصنّف كل حرف (RTL / LTR / رقم / محايد).
- تقسّم السطر إلى مقاطع اتجاهية.
- تكتشف الحروف الخفية (LRM/RLM) والـ embeddings القديمة (`RLE`/`PDF`).
- تعطيك التصحيح: `addingRTLMarks(to:)`.
- فيها واجهة SwiftUI جاهزة (`BidiLabView`) للفحص البصري.

</div>

## License

[MIT](LICENSE) © 2026 Abdulluh.X
