# Chinese Character Writing Practice App

iOS app (Swift 5.9 / SwiftUI) for learning to write Chinese characters with spaced repetition.

## Build

Xcode project generated via XcodeGen from `project.yml`. iOS 17.0+ deployment target.

```
xcodegen generate   # regenerate .xcodeproj from project.yml
```

No external package dependencies — uses only Apple frameworks.

## Architecture

- **UI**: SwiftUI with PencilKit for handwriting input
- **Persistence**: SwiftData (ReviewCard, UserProfile, ReviewLog)
- **Recognition**: Stroke-based matching (StrokeMatcher) with Vision OCR fallback (`VNRecognizeTextRequest`)
- **Audio**: AVFoundation text-to-speech (`AVSpeechSynthesizer`)
- **Spaced repetition**: FSRS v5 algorithm (FSRSEngine.swift)

### Study flow state machine (StudyState.swift)

```
idle → presenting → writing → recognizing → correct → (next card)
                         ↓                                ↓          ↓
                    [Show me]                             ↓     [Review Strokes] → showingStrokeOrder → (next card)
                         ↓                 → incorrect → showingStrokeOrder → tracing → rewriting → recognizing
                         └────────────────────┘                               ↑                     ↓
                                                                              └── (if incorrect) ───┘
                                                                                        (if correct) → (next card)
```

Practice auto-starts on appear (idle is just a loading state). Users can tap "Done" in the toolbar at any time to end practice. The session-complete screen shows stats and a "Practice More" button (no separate "Done" — users switch tabs to leave). During the writing state, a floating "Show me" button (bottom-left, orange) lets users who don't know a character skip directly to the incorrect flow (stroke order → tracing → rewriting). On the correct screen, a "Review Strokes" button lets users optionally watch the stroke order animation before advancing; `isReviewingAfterCorrect` tracks this so `strokeOrderComplete()` skips tracing and goes straight to the next card. The rewrite step uses stroke matching (with Vision OCR fallback) to verify the user wrote the character correctly before advancing — they must get it right.

### Key directories

- `Models/` — CharacterEntry, StrokeData, ReviewCard, FSRSEngine, StudyState
- `Services/` — CharacterDataService, StrokeRenderer, StrokeMatcher, SessionManager, RecognitionService, TTSService
- `Views/Practice/` — PracticeView, PracticeViewModel, WritingCanvasView, StrokeOrderView, TracingCanvasView, CharacterPromptView
- `Views/` — also contains `OnboardingView` (first-launch grade picker)
- `Resources/` — characters.json (1571 chars, grades 1-6), strokes.json (SVG paths + medians from Make Me a Hanzi), PrivacyInfo.xcprivacy (App Store privacy manifest). Stroke data covers ~66% of characters; the remaining use Vision OCR fallback. Stroke data is **lazily decoded** per character on first access (via `CharacterDataService.strokeData(for:)`) to avoid holding all decoded `StrokeData` objects in memory at once. The raw JSON is parsed at init; individual entries are decoded and cached on demand.
- `ChineseWritingTests/` — FSRSEngine unit tests (pure function tests, no SwiftData dependency)

## Important conventions

- Stroke SVG data uses a 1024×1024 coordinate space with Y-axis flipped (origin top-left, y=900 is baseline). StrokeRenderer handles the transform. The SVG parser tracks `lastCubicControl` for proper S/s smooth cubic Bezier reflection.
- CharacterPromptView intentionally hides the Chinese example word text so users recall from audio only.
- WritingCanvasContainer and TracingCanvasView use a solid `Color.white` background behind the transparent PKCanvasView so strokes are visible in both light and dark mode. Do not use `.systemBackground` — it turns black in dark mode, making black ink invisible.
- Recognition is two-tier: **StrokeMatcher** (primary) compares the user's PKDrawing strokes against the expected character's median centerlines from strokes.json. It uses **bounding-box normalization** — each set of strokes (user and expected) is centered at (0.5, 0.5) and scaled by `max(width, height)`, making matching invariant to position and scale within the writing area. Greedy matching uses **soft composite scoring** per stroke: a weighted blend of direction (20%), start-point proximity (20%), polyline distance (30%), and DTW shape distance (30%). A stroke matches if its composite score < 1.0 (where 1.0 means "at threshold on average"). A hard ceiling at 2× any single threshold rejects clearly wrong strokes regardless of composite score. StrokeMatcher uses a **two-pass strategy**: a strict pass with the original thresholds (angle ≤65°, start ≤22%, distance ≤15%, DTW ≤0.18) and grade-based match ratios (75%/80%/85%), then a relaxed pass (thresholds ≈1.4× strict: angle ≤80°, start ≤30%, distance ≤21%, DTW ≤0.25) that requires 90% of strokes to match. Stroke count must be within ±max(2, expected/3). PracticeView syncs `canvasSize` to PracticeViewModel for the normalization.
- **Vision OCR** (fallback) runs only when stroke matching fails or stroke data is unavailable. Uses a lenient confidence threshold (0.15), checks all top-10 candidates, sets `customWords` to the expected character, and enables `usesLanguageCorrection`. RecognitionService renders the PKDrawing to an opaque sRGB 512×512 image (`format.opaque = true`, `preferredRange = .standard`, `format.scale = 1.0`) and scales the drawing up so its longest dimension fills 432pt. Forces a light-mode trait collection via `performAsCurrent` so PencilKit always renders black ink as black regardless of device appearance.
- Two floating buttons appear during the writing state: **"Show me"** (bottom-left, orange) calls `skipAsUnknown()` to enter the incorrect/stroke-review flow when the user doesn't know the character, and **"I got it right"** (bottom-right, green) calls `overrideCorrect()` for when Vision OCR misrecognizes valid handwriting. "I got it right" also shows during recognizing; "Show me" only during writing.
- WritingCanvasView auto-submits after **3 seconds** of drawing inactivity (`idleTimeout`). The timer resets on each stroke change. The same idle timer applies in writing, tracing, and rewriting states.
- The incorrect flow should be encouraging, never use failure language. Use orange (not red) icons and phrases like "Let's practice the strokes!" — the goal is to get users to write it again correctly, not to punish them.
- New card pacing: `nextCard()` priority is relearning → learning → review → existing `.new` cards → introduce fresh card → (if blocked) below-grade verification. Existing `.new` cards (created but never completed because the user quit mid-session) are retried before introducing fresh characters. Fresh cards are gated by relearning count (`maxRelearningBeforeStopNew = 5`) — new cards stop when 5+ recently-missed characters are in the relearning queue. A due-review backstop (`maxDueBeforeStopNew = 50`) also pauses new cards if the review backlog is large (e.g. after time away). When new cards are blocked, the system silently pulls forward below-grade verification cards instead (pacing adjustment).
- **First-launch onboarding**: `OnboardingView` is shown as a `fullScreenCover` on first launch (gated by `UserProfile.hasCompletedOnboarding`). It lets users pick their starting grade before their first practice session. After selection, the profile is saved and assumed-known cards are created for below-grade characters.
- **Reset all progress**: Settings has a "Reset All Progress" button with a two-step confirmation alert. Calls `SessionManager.resetAllProgress()` which deletes all ReviewCards and ReviewLogs via `modelContext.delete(model:)` and resets profile stats (streaks, totalReviews) while preserving settings (grade, character set preference). Re-creates assumed-known cards afterward if starting grade > 1.
- **Starting grade**: Users pick a starting grade (1-6) in Settings (or during onboarding). `introduceNextNewCard()` only introduces characters at or above this grade. Characters below the starting grade get **assumed-known ReviewCards** via `setupAssumedKnownCards()` — pre-seeded with graduated initial stability (7d for 1 grade below, 14d for 2 below, 21d for 3+ below), difficulty set to D0(Good), and staggered due dates spread evenly across the stability window. These cards flow through normal SRS: correct answers increase stability (card fades into background), wrong answers drop the card into relearning for the full treatment (stroke review, rewriting). Assumed-known cards are identified by `state == .review && reps == 0 && lapses == 0`. Their `lastReviewDate` is set to `dueDate - stability` so that elapsed days equals the stability when the card comes due, giving retrievability ≈ 0.9 and proper FSRS scheduling on first real review.
- **Silent difficulty adjustment**: When the user struggles at their starting grade (relearning count blocks new cards), the system automatically mixes in below-grade verification cards (closest grade first). This gives the user characters they're more likely to know, builds confidence, and verifies foundations — without any UI messaging about being "below grade level." When the relearning queue drains, new cards resume automatically.
- Progress page categories: **seen** = a `ReviewCard` exists for the character (cards are created when presented, so existence = seen). **Learning** = seen and rated at least once (`stateRaw != .new`) but stability < 21 days. **Mastered** = stability ≥ 21 days (`FSRSEngine.masteryThreshold`). Session-complete screen shows **correct** (first-try success, rated `.good`) vs. **needed practice** (required stroke review, rated `.again`).
- iPad layout: `AdaptiveLayout` switches to side-by-side HStack on regular width class. Canvas size is 420pt on iPad, 300pt on iPhone. Views that show prompt + canvas pairs use this adaptive layout.
- PracticeView's `mainContent` uses `.frame(maxWidth: .infinity, maxHeight: .infinity)` so the ZStack fills available space on first render. Without this, the PKCanvasView (UIKit) can briefly appear at the top-left corner before SwiftUI's layout engine repositions it.
- WritingCanvasView coordinator must update its `parent` reference in `updateUIView` so SwiftUI binding updates propagate correctly.

## Async task management

- PracticeViewModel uses a single `pendingTask: Task<Void, Never>?` to track in-flight async work (recognition, delayed transitions). The previous task is always cancelled before launching a new one. `endPractice()` and `loadNextCard()` cancel pending tasks. All Task continuations must check `Task.isCancelled` and verify the expected `studyState` after every `await` before mutating state.
- StrokeOrderView stores its animation as a `@State` Task and cancels it in `.onDisappear`. Animation state is reset in `startAnimation()` so it works correctly for subsequent characters.
- TTSService nils out `completion` before calling `stopSpeaking` to prevent the cancelled utterance's delegate from firing the wrong callback. Both `didFinish` and `didCancel` delegate methods are implemented. `didCancel` fires the completion if it's non-nil — this only happens on system-initiated cancellations (e.g. app backgrounded); our own `stop()`/`speak()` nil it first, so their cancellations remain no-ops.
- PracticeView observes `scenePhase` and calls `PracticeViewModel.handleReturnToForeground()` when the app becomes `.active`. This transitions `.presenting → .writing` in case the TTS completion was swallowed during backgrounding, preventing the state machine from getting stuck with unresponsive buttons.

## FSRS implementation notes

- `nextDifficulty` mean-reverts toward D0(3) (Good rating), not D0(4), per FSRS v5 spec.
- `scheduleLearning` and `scheduleReview` compute `newD` first, then pass `newD` (not the old difficulty) to `stabilityAfterSuccess`/`stabilityAfterFailure`.
- `FSRSEngine.init` requires exactly 19 weights (enforced by precondition).

## Testing

Unit test target `ChineseWritingTests` is defined in `project.yml`. Tests cover FSRSEngine (pure functions — retrievability, initial stability/difficulty, difficulty mean-reversion, stability after success/failure, short-term stability, interval calculation, full scheduling for all card states, and FSRS v5 newD ordering). Run via Xcode Test navigator or `xcodebuild test`.

## Character data pipeline

`expand_chars.py`, `expand_chars2.py`, `expand_chars3.py` are generation scripts that expanded characters.json from 494 to 1571 characters. They read existing characters.json, add missing standard curriculum characters (with traditional form, pinyin, meaning, example word), and write the expanded file. Characters are organized by grade level (1-6) based on the PRC 部编版 primary school curriculum. The scripts use pipe-delimited inline data and are idempotent (skip already-present characters). To add more characters, create a new expansion script following the same pattern and run it.

## Privacy manifest

`PrivacyInfo.xcprivacy` declares no tracking, no collected data types, and no required-reason API usage. The app uses only on-device frameworks (Vision, AVFoundation, PencilKit, SwiftData) with no network calls.
