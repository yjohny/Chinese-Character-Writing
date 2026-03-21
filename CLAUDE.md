# Chinese Character Writing Practice App

iOS app (Swift 5.9 / SwiftUI) for learning to write Chinese characters with spaced repetition.

## Build

```
xcodegen generate   # regenerate .xcodeproj from project.yml
```

Xcode project generated via XcodeGen from `project.yml`. iOS 17.0+ deployment target. No external package dependencies — uses only Apple frameworks (SwiftUI, SwiftData, PencilKit, Vision, AVFoundation).

## Architecture

- **UI**: SwiftUI with PencilKit for handwriting input
- **Persistence**: SwiftData (ReviewCard, UserProfile, ReviewLog)
- **Recognition**: Stroke-based matching (StrokeMatcher) with Vision OCR fallback
- **Audio**: AVFoundation TTS (`TTSService`), AVAudioEngine synthesized sound effects (`SoundService`)
- **Spaced repetition**: FSRS v5 algorithm (`FSRSEngine.swift`)

### Key directories

- `Models/` — CharacterEntry, StrokeData, ReviewCard, FSRSEngine, StudyState, Milestone
- `Services/` — CharacterDataService, StrokeRenderer, StrokeMatcher, SessionManager, RecognitionService, TTSService, SoundService
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

## Caching strategy

SessionManager caches aggressively to avoid repeated SwiftData fetches:
- **UserProfile** — `cachedProfile` (singleton, mutated in place, never changes identity)
- **Known card characters** — `knownCardCharacters: Set<String>` for `nextCard()`/`introduceNextNewCard()`. Invalidated on bulk insert, updated incrementally on single-card creation.
- **Cards by character** — `cachedCardsByCharacter` with `statsRevision`-based invalidation for CharacterBrowseView.
- **`statsRevision`** counter (tracked by `@Observable`) — incremented after `rateCard()` and `setupAssumedKnownCards()`. Views that read stats must touch this property to get re-rendered.
- **`fetchFirstDueCard()`** uses `fetchLimit: 1`; **`countDueCards()`** uses `fetchCount` — avoids materializing all due cards.
- **Stroke data** — lazily decoded per character, raw JSON evicted after decode. Parsed SVG paths cached in `StrokeRenderer.pathCache` (`NSCache`, auto-evicts under pressure). Next card's stroke data is prefetched during correct/incorrect screen.
- All `modelContext.save()` calls go through `SessionManager.saveContext()` which logs errors.

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
