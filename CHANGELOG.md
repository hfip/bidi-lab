# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.1] - 2026-11-19

### Fixed

- A leading RLM was reported as a stray control — the exact fix the package recommends
  produced a warning. A paragraph mark at the start of a line (after indentation) is now
  treated as intentional.
- `firstStrongDirection` did not treat RLM/LRM as strong direction hints, so a line that
  had already been fixed with an RLM still reported `latinInitial`.
- Added regression tests: the output of `addingRTLMarks(to:)` must be issue-free.
- 29 tests.

## [0.1.0] - 2026-11-19

Initial release: character classification, run grouping, stray-control / legacy-embedding
/ Latin-initial diagnostics, `addingRTLMarks(to:)`, `removingControlCharacters(from:)`,
and the optional SwiftUI `BidiLabView`.
