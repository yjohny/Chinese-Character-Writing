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

Practice auto-starts on appear (idle is just a loading state). Users can tap "Done" in the toolbar at any time to end practice. The session-complete screen shows stats and a "Practice More" button (no separate "Done" — users switch tabs to leave). During the writing state, a floating "Show me" button (bottom-left, orange) lets users who don't know a character skip directly to the incorrect flow (stroke order → tracing → rewriting). On the correct screen, a "Review Strokes" button lets users optionally watch the stroke order animation before advancing; `isReviewingAfterCorrect` tracks this so `strokeOrderComplete()` skips tracing and goes straight to the next card. The rewrite step uses stroke matching (with Vision OCR fallback) to verify the user wrote the character correctly before advancing — they must get it right. After 3 consecutive failed rewrite attempts, a "Show strokes again" button (orange) appears, letting the user re-enter the stroke order → tracing → rewriting flow rather than being stuck. `rewriteAttempts` tracks this counter; it resets when entering tracing, showing strokes again, on successful rewrite recognition, loading the next card, or ending practice.

### Key directories

- `Models/` — CharacterEntry, StrokeData, ReviewCard, FSRSEngine, StudyState
- `Services/` — CharacterDataService, StrokeRenderer, StrokeMatcher, SessionManager, RecognitionService, TTSService
- `Views/Practice/` — PracticeView, PracticeViewModel, WritingCanvasView, StrokeOrderView, TracingCanvasView, CharacterPromptView
- `Resources/` — characters.json (3,000 chars: grades 1-6 cover the full 部编版 写字表 curriculum, grade 7 "Expansion" adds ~500 识字表-only recognition characters), strokes.json (SVG paths + medians from Make Me a Hanzi). Stroke data is **lazily decoded** per character on first access (via `CharacterDataService.strokeData(for:)`) to avoid holding all decoded `StrokeData` objects in memory at once. The file is read synchronously at init but **parsed on a background thread** (`Task.detached` + `JSONSerialization`); individual entries are decoded and cached on demand. If `strokeData(for:)` is called before parsing completes, it returns nil and recognition falls through to Vision OCR for that card. After decoding, the raw JSON entry is evicted from `rawStrokeEntries` to avoid keeping both the Foundation objects and the decoded `StrokeData` in memory.
- `scripts/` — `generate_expanded_data.py` generates characters.json and strokes.json from open-source data (Make Me a Hanzi, CC-CEDICT, hanziDB). Downloads source data to `scripts/data/` (gitignored). The 494 original hand-curated entries are preserved; the remaining ~2,506 characters are generated with frequency-based grade assignment and automated example word selection (with curated overrides for the most common characters). `generate_icon.py` creates the 1024×1024 app icon (写 in white serif over an orange gradient with faint 米字格 grid lines) — requires Pillow and a CJK font (Noto Serif CJK preferred).

## Important conventions

- Stroke SVG data uses a 1024×1024 coordinate space with Y-axis flipped (origin top-left, y=900 is baseline). StrokeRenderer handles the transform. The SVG parser tracks `lastCubicControl` for proper S/s smooth cubic Bezier reflection.
- CharacterPromptView intentionally hides the Chinese example word text so users recall from audio only.
- WritingCanvasContainer and TracingCanvasView use a solid `Color.white` background behind the transparent PKCanvasView so strokes are visible in both light and dark mode. Do not use `.systemBackground` — it turns black in dark mode, making black ink invisible.
- Recognition is two-tier: **StrokeMatcher** (primary) compares the user's PKDrawing strokes against the expected character's median centerlines from strokes.json. It uses **bounding-box normalization** — each set of strokes (user and expected) is centered at (0.5, 0.5) and scaled by `max(width, height)`, making matching invariant to position and scale within the writing area. Greedy matching uses **soft composite scoring** per stroke: a weighted blend of direction (20%), start-point proximity (20%), polyline distance (30%), and DTW shape distance (30%). A stroke matches if its composite score < 1.0 (where 1.0 means "at threshold on average"). A hard ceiling at 2× any single threshold rejects clearly wrong strokes regardless of composite score. StrokeMatcher uses a **two-pass strategy**: a strict pass with the original thresholds (angle ≤65°, start ≤22%, distance ≤15%, DTW ≤0.18) and grade-based match ratios (75%/80%/85%), then a relaxed pass (thresholds ≈1.4× strict: angle ≤80°, start ≤30%, distance ≤21%, DTW ≤0.25) that requires 90% of strokes to match. Stroke count must be within ±max(2, expected/3). PracticeView syncs `canvasSize` to PracticeViewModel for the normalization.
- **Traditional mode**: Stroke data is simplified-only (from Make Me a Hanzi). `resolveStrokeData(for:)` returns `nil` when the traditional form differs from simplified, so recognition falls through entirely to Vision OCR (which handles traditional correctly via `zh-Hant`). For characters where simplified == traditional, stroke matching works normally. Stroke order animation is unavailable for differing traditional characters; the incorrect flow skips directly to rewriting.
- **Vision OCR** (fallback) runs only when stroke matching fails or stroke data is unavailable. Uses a lenient confidence threshold (0.15), checks all top-10 candidates, sets `customWords` to the expected character, and enables `usesLanguageCorrection`. RecognitionService renders the PKDrawing to an opaque sRGB 512×512 image (`format.opaque = true`, `preferredRange = .standard`, `format.scale = 1.0`) and scales the drawing up so its longest dimension fills 432pt. Forces a light-mode trait collection via `performAsCurrent` so PencilKit always renders black ink as black regardless of device appearance.
- Two floating buttons appear during practice: **"Show me"** (bottom-left, orange) calls `skipAsUnknown()` to enter the incorrect/stroke-review flow when the user doesn't know the character — visible only during `.writing`. **"I got it right"** (bottom-right, green) calls `overrideCorrect()` for when recognition misidentifies valid handwriting — visible during `.recognizing`, `.incorrect`, and `.rewriting`. During `.recognizing`/`.incorrect` it requires enough strokes (`hasDrawnEnoughForOverride`: at least `max(2, expectedStrokes/2)`) to prevent gaming. During `.rewriting` it appears after a failed recognition attempt (`rewriteAttempts >= 1`) or while recognition is running — this is critical for traditional characters with no stroke data, where the "Show strokes again" escape hatch is unavailable. The rewriting override rates as `.again` (same as successful rewrite) and advances to the next card. The incorrect screen pauses for 2 seconds before auto-transitioning to stroke order, giving legitimate users time to tap the override.
- WritingCanvasView auto-submits after **3 seconds** of drawing inactivity (`idleTimeout`). The timer resets on each stroke change. The same idle timer applies in writing, tracing, and rewriting states. When transitioning from `.presenting` to `.writing`, `transitionToWriting()` checks whether strokes were drawn during TTS playback and schedules a ViewModel-side auto-submit task if so, since the UIKit idle timer would have already fired and been silently ignored during `.presenting`.
- The incorrect flow should be encouraging, never use failure language. Use orange (not red) icons and phrases like "Let's practice the strokes!" — the goal is to get users to write it again correctly, not to punish them.
- **Stats refresh**: SessionManager has a `statsRevision` counter (tracked by `@Observable`) that's incremented after `rateCard()` and `setupAssumedKnownCards()`. StatsView reads `statsRevision` in its body so it re-renders when reviews change the underlying data. Without this, SwiftData query results accessed via methods wouldn't trigger `@Observable` re-evaluation.
- **Persistence**: All `modelContext.save()` calls go through `SessionManager.saveContext()` which logs errors rather than silently swallowing them (`try?`). Settings changes (grade, character set) are routed through `SessionManager.updateStartingGrade()`/`updateUseTraditional()` for the same reason.
- New card pacing: `nextCard()` priority is relearning → learning → review → existing `.new` cards → introduce fresh card → (if blocked) below-grade verification. Existing `.new` cards (created but never completed because the user quit mid-session) are retried before introducing fresh characters. Fresh cards are gated by relearning count (`maxRelearningBeforeStopNew = 5`) — new cards stop when 5+ recently-missed characters are in the relearning queue. A due-review backstop (`maxDueBeforeStopNew = 50`) also pauses new cards if the review backlog is large (e.g. after time away). When new cards are blocked, the system silently pulls forward below-grade verification cards instead (pacing adjustment).
- **Grade 7 "Expansion" tier**: Contains ~500 识字表-only (recognition table) characters — common, high-frequency characters that the 部编版 school curriculum marks as recognition-only because young children lack the motor skills to write them. Adult learners benefit from writing practice with these characters. `CharacterEntry.gradeName(for:)` maps grade 7 → "Expansion" for display in the UI (SettingsView picker, GradeProgressRow). StrokeMatcher uses the same 85% strict match ratio as grades 5-6.
- **Starting grade**: Users pick a starting grade (1-7, where 7 is "Expansion") in Settings. `introduceNextNewCard()` only introduces characters at or above this grade. Characters below the starting grade get **assumed-known ReviewCards** via `setupAssumedKnownCards()` — pre-seeded with graduated initial stability (7d for 1 grade below, 14d for 2 below, 21d for 3+ below), difficulty set to D0(Good), and staggered due dates spread evenly across the stability window. These cards flow through normal SRS: correct answers increase stability (card fades into background), wrong answers drop the card into relearning for the full treatment (stroke review, rewriting). Assumed-known cards are identified by `state == .review && reps == 0 && lapses == 0`. Their `lastReviewDate` is set to `dueDate - stability` so that elapsed days equals the stability when the card comes due, giving retrievability ≈ 0.9 and proper FSRS scheduling on first real review.
- **Silent difficulty adjustment**: When the user struggles at their starting grade (relearning count blocks new cards), the system automatically mixes in below-grade verification cards (closest grade first). This gives the user characters they're more likely to know, builds confidence, and verifies foundations — without any UI messaging about being "below grade level." When the relearning queue drains, new cards resume automatically.
- Progress page categories: **seen** = a `ReviewCard` exists for the character (cards are created when presented, so existence = seen). **Learning** = seen and rated at least once (`stateRaw != .new`) but stability < 21 days. **Mastered** = stability ≥ 21 days (`FSRSEngine.masteryThreshold`). Session-complete screen shows **correct** (first-try success, rated `.good`) vs. **needed practice** (required stroke review, rated `.again`).
- iPad layout: `AdaptiveLayout` switches to side-by-side HStack on regular width class. Canvas size is 420pt on iPad, 300pt on iPhone. Views that show prompt + canvas pairs use this adaptive layout.
- PracticeView's `mainContent` uses `.frame(maxWidth: .infinity, maxHeight: .infinity)` so the ZStack fills available space on first render. Without this, the PKCanvasView (UIKit) can briefly appear at the top-left corner before SwiftUI's layout engine repositions it.
- WritingCanvasView coordinator must update its `parent` reference in `updateUIView` so SwiftUI binding updates propagate correctly.

## Async task management

- PracticeViewModel uses a single `pendingTask: Task<Void, Never>?` to track in-flight async work (recognition, delayed transitions). The previous task is always cancelled before launching a new one. `endPractice()` and `loadNextCard()` cancel pending tasks and reset transient UI flags (`isRecognizing`, `isReviewingAfterCorrect`, `rewriteAttempts`) to prevent stale state from leaking across sessions. All Task continuations must check `Task.isCancelled` and verify the expected `studyState` after every `await` before mutating state.
- StrokeOrderView stores its animation as a `@State` Task and cancels it in `.onDisappear`. Animation state is reset in `startAnimation()` so it works correctly for subsequent characters.
- TTSService uses a `generation` counter (`nonisolated(unsafe)`, safe because writes are MainActor-only and UInt loads are atomic on 64-bit) to prevent stale `didCancel` delegate callbacks from firing the wrong completion. `speak()`/`stop()` bump the generation before stopping; `didCancel` captures the generation and only fires the completion if it still matches — preventing the race where an enqueued `Task { @MainActor in }` from the old cancellation runs after `speak()` has already set a new completion. `didFinish` fires the completion unconditionally (generation check unnecessary since the utterance completed normally).
- CelebrationView stores its cleanup Task in `@State` and cancels the previous one before launching a new animation, preventing rapid re-triggers from cutting animations short.
- PracticeView observes `scenePhase` and calls `PracticeViewModel.handleReturnToForeground()` when the app becomes `.active`. This calls `transitionToWriting()` which transitions `.presenting → .writing` and schedules auto-submit if strokes were drawn during backgrounding, preventing the state machine from getting stuck with unresponsive buttons.
- PracticeViewModel keeps a persistent `UINotificationFeedbackGenerator` and calls `prepare()` after each use so the Taptic Engine is ready for the next haptic.
- TTSService sets the audio session category at init but only activates it on demand in `speak()`. `stop()` deactivates with `.notifyOthersOnDeactivation` so background music/podcasts can resume after practice ends.
- `nextCard()` uses `fetchFirstDueCard()` (fetchLimit: 1) for card selection and `countDueCards()` (fetchCount) for pacing gates — avoids materializing all due cards into memory.

## FSRS implementation notes

- `nextDifficulty` mean-reverts toward D0(3) (Good rating), not D0(4), per FSRS v5 spec.
- `scheduleLearning` and `scheduleReview` compute `newD` first, then pass `newD` (not the old difficulty) to `stabilityAfterSuccess`/`stabilityAfterFailure`.
- `FSRSEngine.init` requires exactly 19 weights (enforced by precondition).
