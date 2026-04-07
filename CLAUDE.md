# Chinese Character Writing Practice App

iOS app (Swift 5.9 / SwiftUI) for learning to write Chinese characters with spaced repetition.

Bundle ID: `com.chinesewriting.app` · Version 1.0 · iOS 17.0+

## Build

```
xcodegen generate   # regenerate .xcodeproj from project.yml
```

Xcode project generated via XcodeGen from `project.yml`. iOS 17.0+ deployment target. No external package dependencies — uses only Apple frameworks (SwiftUI, SwiftData, PencilKit, Vision, AVFoundation).

## Architecture

- **UI**: SwiftUI with PencilKit for handwriting input
- **Persistence**: SwiftData via `SchemaV1: VersionedSchema` (ReviewCard, UserProfile, ReviewLog) with `ChineseWritingMigrationPlan`
- **Recognition**: Stroke-based matching (StrokeMatcher) with Vision OCR fallback
- **Audio**: AVFoundation TTS (`TTSService`), AVAudioEngine synthesized sound effects (`SoundService`)
- **Spaced repetition**: FSRS v5 algorithm (`FSRSEngine.swift`)
- **Logging**: `os.Logger` (subsystem `com.chinesewriting.app`, per-module categories)
- **Diagnostics**: `MetricKitService` subscribes to `MXMetricManager` at launch and logs crash/hang/CPU/disk-write payloads via `os.Logger` — no third-party SDK, no permissions

### Key directories

- `Models/` — CharacterEntry, StrokeData, ReviewCard, ReviewLog, UserProfile, SchemaV1, FSRSEngine, StudyState, Milestone
- `Services/` — CharacterDataService, StrokeRenderer, StrokeMatcher, SessionManager, RecognitionService, TTSService, SoundService, MetricKitService
- `Views/Practice/` — PracticeView, PracticeViewModel, WritingCanvasView, StrokeOrderView, TracingCanvasView, CharacterPromptView, DailyProgressRing, MilestoneView
- `Views/Browse/` — CharacterBrowseView (searchable character dictionary with grade filtering)
- `Views/Stats/` — StatsView, ReviewHeatmapView, GradeProgressRow
- `Views/Settings/` — SettingsView
- `Views/Onboarding/` — OnboardingView (first-run 4-page flow with grade picker)
- `Resources/` — characters.json (3,000 chars, grades 1-7), strokes.json (SVG paths + medians from Make Me a Hanzi)
- `scripts/` — `generate_expanded_data.py` (data generation), `generate_icon.py` (app icon)

### Study flow state machine (StudyState.swift)

```
idle → presenting → writing → recognizing → correct → (next card)
                         ↓                       ↓          ↓
                    [Show me]                    ↓     [Review Strokes] → showingStrokeOrder → (next card)
                         ↓        → incorrect → showingStrokeOrder → tracing → rewriting → recognizing
                         └──────────┘                                ↑                     ↓
                                                                     └── (if incorrect) ───┘
                                                                               (if correct) → (next card)
```

## Critical conventions (must follow to avoid bugs)

- **White backgrounds on all canvas/stroke views.** WritingCanvasContainer, TracingCanvasView, and StrokeOrderView must use `Color.white`, never `Color(.systemBackground)`. SystemBackground turns black in dark mode, making black ink/strokes invisible.
- **Encouraging language only in incorrect flow.** Use orange (not red) icons. Phrases like "Let's practice the strokes!" — never failure language. Goal is motivation, not punishment.
- **CharacterPromptView hides Chinese example text** so users recall from audio only. Don't show the Chinese word.
- **All Task continuations must check `Task.isCancelled` and verify the expected `studyState`** after every `await` before mutating state. PracticeViewModel uses a single `pendingTask` — always cancel the previous one before launching a new one.
- **Reset `showCelebration = false` before loading the next card.** Without this, `CelebrationView.onChange(of: isActive)` won't fire on consecutive correct answers because the value is already `true`.
- **WritingCanvasView coordinator must update `parent` in `updateUIView`** so SwiftUI binding updates propagate correctly.
- **PracticeView's `mainContent` needs `.frame(maxWidth: .infinity, maxHeight: .infinity)`** on the ZStack — without it, the PKCanvasView (UIKit) briefly appears at top-left before SwiftUI repositions it.

## Persistence schema

SwiftData models are wrapped in `SchemaV1: VersionedSchema` so that future schema changes can be expressed as `MigrationStage`s in `ChineseWritingMigrationPlan`. `ChineseWritingApp` instantiates `ModelContainer(for: SchemaV1.self, migrationPlan: ChineseWritingMigrationPlan.self, configurations: ModelConfiguration())` and crashes loudly via `os.Logger` + `fatalError` if creation fails — persistence is required for the app to function.

**To add a schema change:**
1. Create `SchemaV2` enum with new model shapes (typically by namespacing copies inside the enum)
2. Add `SchemaV2.self` to `ChineseWritingMigrationPlan.schemas`
3. Add a `MigrationStage` (`.lightweight` for additive, `.custom` for renames/transforms)
4. Update `ChineseWritingApp` to reference the latest version

**Database-level constraints (do not weaken):**
- `ReviewCard.character` is `@Attribute(.unique)` — duplicate cards for the same character are impossible
- `UserProfile.key` is `@Attribute(.unique)` with default value `UserProfile.singletonKey` (`"default"`) — enforces singleton at the DB layer. `SessionManager.fetchProfile()` queries by this key with `fetchLimit: 1`.
- `ReviewCard.logs ↔ ReviewLog.card` is a `@Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)` — `ReviewLog`s cascade-delete with their parent card. `SessionManager.rateCard()` must set `log.card = card` before insert. `ReviewLog.character` is also kept as a redundant string for analytics resilience.
- `UserProfile.achievedMilestones: [String]` is stored natively (no comma-string workaround). Use `hasAchieved(_:)` / `markAchieved(_:)` helpers.
- All `@Model` properties must have default values (required for lightweight migration).

**JSON export** includes `"schemaVersion": 1` and `"appVersion": "1.0"` so a future import feature can detect the source schema.

## Failure modes

- **`CharacterDataService` hard-fails** if `characters.json` is missing or malformed — calls `fatalError` rather than running with an empty character set, since the resource is bundled at build time and a missing file means a corrupted build. `strokes.json` failures are logged but non-fatal because recognition falls back to Vision OCR.
- **`ChineseWritingApp` hard-fails** if `ModelContainer` creation throws — persistence is required, so the failure is logged via `os.Logger` and then `fatalError` so it's captured in MetricKit / crash reports rather than silently corrupting state.
- **`SessionManager.saveContext()` soft-fails** — logs the error and sets `lastSaveError` for the UI banner. Called for every persistent mutation.
- **`SoundService` is lazy** — only an `AVAudioFormat` is built in `init`. The `AVAudioEngine`, player node, and per-sound buffers are created on first `play()` call so launch isn't paying for synthesis cost upfront.

## Privacy

`ChineseWriting/PrivacyInfo.xcprivacy` declares required-reason API usage (file timestamp `C617.1`, disk space `E174.1`) used by SwiftData/Foundation. The app collects no user data, does no tracking, and requires no permissions. If you add a new framework that uses required-reason APIs (e.g., UserDefaults, system boot time), update this file or the App Store will reject the build.

## Caching strategy

SessionManager caches aggressively to avoid repeated SwiftData fetches:
- **UserProfile** — `cachedProfile` (singleton, mutated in place, never changes identity)
- **Known card characters** — `knownCardCharacters: Set<String>` for `nextCard()`/`introduceNextNewCard()`. Invalidated on bulk insert, updated incrementally on single-card creation.
- **Cards by character** — `cachedCardsByCharacter` with `statsRevision`-based invalidation for CharacterBrowseView.
- **`statsRevision`** counter (tracked by `@Observable`) — incremented after `rateCard()` and `setupAssumedKnownCards()`. Views that read stats must touch this property to get re-rendered.
- **`fetchFirstDueCard()`** uses `fetchLimit: 1`; **`countDueCards()`** uses `fetchCount` — avoids materializing all due cards.
- **Stroke data** — lazily decoded per character, raw JSON evicted after decode. Parsed SVG paths cached in `StrokeRenderer.pathCache` (`NSCache`, auto-evicts under pressure). Next card's stroke data is prefetched during correct/incorrect screen.
- All `modelContext.save()` calls go through `SessionManager.saveContext()` which logs errors via `os.Logger` and sets `SessionManager.lastSaveError`. ContentView observes that property and shows a red `SaveErrorBanner` overlay so users know if their progress isn't persisting. Cleared on the next successful save or on tap.

## Recognition

Two-tier: **StrokeMatcher** (primary) then **Vision OCR** (fallback).

- StrokeMatcher uses bounding-box normalization, soft composite scoring (direction 20%, start-point 20%, polyline distance 30%, DTW 30%), two-pass strategy (strict then relaxed), grade-based match ratios. DTW uses Sakoe-Chiba band constraint for performance. See code constants for exact thresholds.
- **Traditional mode**: Stroke data is simplified-only. `resolveStrokeData(for:)` returns `nil` when traditional differs from simplified — recognition falls through to Vision OCR (`zh-Hant`). Stroke order animation unavailable for differing traditional characters.
- **Vision OCR** renders PKDrawing to 512×512 opaque sRGB image with light-mode traits forced (so black ink renders as black in dark mode). Lenient confidence threshold (0.15), checks top-10 candidates.

## Card scheduling

- `nextCard()` priority: relearning → learning → review → existing `.new` → introduce fresh → below-grade verification.
- Fresh cards gated by `maxRelearningBeforeStopNew` (5) and `maxDueBeforeStopNew` (50). When blocked, below-grade verification cards mix in silently (no UI messaging about difficulty).
- **Starting grade** (1-7): Characters below get assumed-known ReviewCards via `setupAssumedKnownCards()` with graduated initial stability and staggered due dates. Identified by `state == .review && reps == 0 && lapses == 0`.
- **Grade 7 "Expansion"**: ~500 识字表-only recognition characters. `gradeName(for: 7)` → "Expansion".
- **Progress categories**: Seen = ReviewCard exists. Learning = rated at least once, stability < 21d. Mastered = stability ≥ 21d (`FSRSEngine.masteryThreshold`).

## Async patterns

- PracticeViewModel: single `pendingTask` for all in-flight async work. `endPractice()` and `loadNextCard()` cancel it and reset all transient UI flags.
- StrokeOrderView: `@State` Task for animation, cancelled in `.onDisappear`. Tap to skip.
- TTSService: `generation` counter (`nonisolated(unsafe)`) prevents stale `didCancel` delegate callbacks. `didFinish` fires unconditionally; `didCancel` checks generation match.
- CelebrationView/DailyGoalOverlayView/MilestoneView: `@State` Task for auto-dismiss, cancelled on re-trigger/disappear.
- Audio session: TTSService owns lifecycle. Category set at init, activated on `speak()`, deactivated on `stop()` with `.notifyOthersOnDeactivation`.
- WritingCanvasView auto-submits after 3s idle (`idleTimeout`). `transitionToWriting()` handles strokes drawn during TTS playback.

## Features reference

- **Floating buttons**: "Show me" (orange, writing state only) and "I got it right" (green, recognizing/incorrect/rewriting states with stroke count and attempt gates).
- **Undo**: All canvas views. Reconstructs PKDrawing without last stroke. Light haptic feedback on undo.
- **Character browse**: Search by character, pinyin (with or without tone marks via `CharacterEntry.stripTones`), or meaning. Grade filtering. Review status badges. `pinyinNormalized` index precomputed in CharacterDataService.
- **Gamification**: Daily goal (DailyProgressRing + celebration overlay), milestones (mastery/grade/streak thresholds with confetti), sound effects (synthesized sine-wave tones, no bundled files).
- **Session resume**: Brief "Resuming session" toast when returning to Practice tab mid-session.
- **Export**: JSON with all ReviewCards, ReviewLogs (including wasOverride, visionConfidence), and profile stats.
- **Accessibility**: VoiceOver labels/hints on all views, `.allowsDirectInteraction` on canvases, `.isModal` on overlays, semantic font styles for Dynamic Type.
- **iPad**: `AdaptiveLayout` uses HStack on regular width. Canvas 420pt (iPad) / 300pt (iPhone).

## FSRS implementation notes

- `nextDifficulty` mean-reverts toward D0(3) (Good), not D0(4), per FSRS v5 spec.
- `scheduleLearning`/`scheduleReview` compute `newD` first, then pass `newD` to stability functions.
- `FSRSEngine.init` requires exactly 19 weights (enforced by precondition).

## Logging

Use `os.Logger` — never `print()`. Each service file declares a module-level logger:

```swift
import os.log
private let logger = Logger(subsystem: "com.chinesewriting.app", category: "CategoryName")
```

Categories: `CharacterData`, `Session`, `TTS`, `Recognition`, `Settings`. All errors use `logger.error()`.

## Attribution

Stroke order data from [Make Me a Hanzi](https://github.com/skishore/makemeahanzi) (LGPL / CC-BY-SA). Credited in Settings → Acknowledgments. Any new third-party data must be attributed there.
