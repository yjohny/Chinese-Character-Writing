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
                                           → incorrect → showingStrokeOrder → tracing → rewriting → (next card)
```

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
