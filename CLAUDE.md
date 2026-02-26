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
- **Recognition**: Vision framework OCR (`VNRecognizeTextRequest`) — supports zh-Hans and zh-Hant
- **Audio**: AVFoundation text-to-speech (`AVSpeechSynthesizer`)
- **Spaced repetition**: FSRS v5 algorithm (FSRSEngine.swift)

### Study flow state machine (StudyState.swift)

```
idle → presenting → writing → recognizing → correct → (next card)
                                           → incorrect → showingStrokeOrder → tracing → rewriting → recognizing
                                                                                        ↑                     ↓
                                                                                        └── (if incorrect) ───┘
                                                                                                  (if correct) → (next card)
```

Practice auto-starts on appear (idle is just a loading state). Users can tap "Done" in the toolbar at any time to end practice. The rewrite step uses Vision recognition to verify the user wrote the character correctly before advancing — they must get it right.

### Key directories

- `Models/` — CharacterEntry, StrokeData, ReviewCard, FSRSEngine, StudyState
- `Services/` — CharacterDataService, StrokeRenderer, SessionManager, RecognitionService, TTSService
- `Views/Practice/` — PracticeView, PracticeViewModel, WritingCanvasView, StrokeOrderView, TracingCanvasView, CharacterPromptView
- `Resources/` — characters.json (494 chars, grades 1-6), strokes.json (SVG paths + medians from Make Me a Hanzi)

## Important conventions

- Stroke SVG data uses a 1024×1024 coordinate space with Y-axis flipped (origin top-left, y=900 is baseline). StrokeRenderer handles the transform.
- CharacterPromptView intentionally hides the Chinese example word text so users recall from audio only.
- WritingCanvasContainer uses a solid `.systemBackground` behind the transparent PKCanvasView so strokes are visible in both light and dark mode.
- Recognition uses a lenient confidence threshold (0.15) and checks all top-10 candidates, not just the #1 result.
- There is a manual "I got it right" override button for when Vision OCR misrecognizes valid handwriting.
- The incorrect flow should be encouraging, never use failure language. Use orange (not red) icons and phrases like "Let's practice the strokes!" — the goal is to get users to write it again correctly, not to punish them.
- New card pacing: max 10 new cards/day (`maxNewPerDay`), paused if >20 reviews due (`maxDueBeforeStopNew`). The daily count is derived from ReviewLog (stabilityBefore == 0) so it persists across app restarts.
- iPad layout: `AdaptiveLayout` switches to side-by-side HStack on regular width class. Canvas size is 420pt on iPad, 300pt on iPhone. Views that show prompt + canvas pairs use this adaptive layout.
- WritingCanvasView coordinator must update its `parent` reference in `updateUIView` so SwiftUI binding updates propagate correctly.
