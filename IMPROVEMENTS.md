# App Improvement Ideas

Brainstormed improvements for the Chinese Character Writing Practice app, organized by category and rough priority.

---

## 1. Learning Features

### 1a. Character Search & Browse
**Impact: High | Effort: Medium**

Currently there's no way to look up a specific character. Add a searchable character dictionary view (new tab or section in Progress) where users can:
- Search by pinyin, meaning, or character
- Browse by grade level
- See character details: pinyin, meaning, example words, stroke count
- Tap to practice a specific character on demand
- See their review status for each character (new / learning / mastered)

This is probably the single highest-impact missing feature — users frequently want to practice a specific character they just encountered.

### 1b. Radical/Component Breakdown
**Impact: Medium | Effort: High**

Show character decomposition (e.g., 游 = 氵+ 方 + 㫃). This helps learners understand character structure and memorize more efficiently. Would require adding radical/component data to characters.json (available from Make Me a Hanzi's `dictionary.txt`).

### 1c. Stroke Count Display
**Impact: Low | Effort: Low**

Show the expected stroke count during the writing state. This gives learners a helpful hint without revealing the character, and helps them self-check before submitting. The data is already available in strokes.json.

### 1d. Wrong Stroke Highlighting
**Impact: High | Effort: High**

After an incorrect attempt, highlight which specific strokes were wrong (red) vs. correct (green) by overlaying the user's strokes against the expected ones. Currently the feedback is binary (correct/incorrect) — per-stroke feedback would be far more instructive.

### 1e. Meaning Quiz Mode
**Impact: Medium | Effort: Medium**

An optional mode where the user sees only the pinyin (no audio example word) and must write the character. Tests deeper recall. Could be a toggle in settings or a separate practice mode.

---

## 2. User Experience

### 2a. Onboarding / First-Run Experience
**Impact: High | Effort: Medium**

New users are dropped straight into practice with no context. Add a brief onboarding flow:
- Explain the practice loop (write → check → review strokes → rewrite)
- Let users pick their starting grade level upfront
- Show what "Show me" and "I got it right" buttons do
- Optionally assess existing knowledge (show 5-10 characters, let user mark known/unknown)

### 2b. Session Configuration
**Impact: Medium | Effort: Low**

Let users configure session length before starting (e.g., "Practice 5 / 10 / 20 characters" or "Practice for 5 / 10 / 15 minutes"). Currently the session is open-ended — users must manually tap "Done." A bounded session helps users fit practice into a routine.

### 2c. Undo Last Stroke
**Impact: Medium | Effort: Low**

Add an undo button alongside Clear on the writing canvas. Clearing the entire canvas when you made one wrong stroke is frustrating. PencilKit supports undo natively via `PKCanvasView.undoManager`.

### 2d. Dark Mode Polish
**Impact: Low | Effort: Low**

The app forces white canvas backgrounds to avoid ink visibility issues. Consider adding a dark-mode canvas option with light-colored ink, or at minimum ensure all non-canvas UI elements respect the system appearance gracefully.

### 2e. Haptic Feedback on Tracing
**Impact: Low | Effort: Low**

Add subtle haptic feedback during tracing when the user's stroke stays on/goes off the guide path. This would give real-time tactile feedback without visual clutter.

---

## 3. Progress & Motivation

### 3a. Review Forecast / Heatmap
**Impact: Medium | Effort: Medium**

Show a calendar heatmap (like GitHub's contribution graph) on the Progress tab, visualizing daily review counts over the past weeks/months. Also show a forecast: "12 reviews due tomorrow, 25 due this week" — this helps users plan and builds a visual streak motivator.

### 3b. Character Mastery Timeline
**Impact: Low | Effort: Medium**

In the character detail view (from the browse feature), show when the character was first seen, review history, and current FSRS stability/retrievability. Power users love seeing their learning curve.

### 3c. Weekly/Monthly Summary
**Impact: Medium | Effort: Medium**

Push notification or in-app summary: "This week you reviewed 73 characters, mastered 5 new ones, and maintained a 12-day streak." Reinforces progress and re-engages lapsed users.

### 3d. Leaderboard / Social Features
**Impact: Medium | Effort: High**

Optional anonymous leaderboard (characters mastered, streak length). Requires a backend, so this is a longer-term idea. Even a local "compare with average" stat could work without networking.

---

## 4. Content & Data

### 4a. Custom Word Lists
**Impact: Medium | Effort: Medium**

Let users create custom character lists (e.g., "HSK 1", "Characters from my textbook chapter 3") and practice them specifically. Could import from a text file or let users add characters one by one.

### 4b. Example Sentence Context
**Impact: Medium | Effort: Medium**

Show a full example sentence (not just a two-character word) for each character. This gives richer context for meaning and usage. Would require adding sentence data to characters.json.

### 4c. Pinyin Tone Practice
**Impact: Low | Effort: Medium**

After writing the character correctly, optionally quiz the user on the pinyin tone (show the character, pick the correct tone). Reinforces the sound-character connection.

### 4d. Character Animation Speed Control
**Impact: Low | Effort: Low**

Let users control stroke order animation speed (slow/normal/fast). The current fixed timing (550ms per stroke) works for simple characters but feels slow for experienced users reviewing easy characters, and might be fast for beginners on complex ones.

---

## 5. Technical / Platform

### 5a. iPad Split View & Keyboard Shortcuts
**Impact: Medium | Effort: Medium**

Better iPad support: work in Split View / Slide Over, add keyboard shortcuts (Enter to submit, Escape to clear, Space to skip). The adaptive layout exists but there's no keyboard shortcut support.

### 5b. Widget
**Impact: Medium | Effort: Medium**

iOS home screen widget showing: daily progress ring, streak count, next review time. Keeps the app top-of-mind and encourages daily practice.

### 5c. iCloud Sync
**Impact: High | Effort: Medium**

Sync review data across devices via CloudKit. SwiftData supports CloudKit integration. Users who practice on both iPhone and iPad would benefit significantly.

### 5d. Siri Shortcuts / App Intents
**Impact: Low | Effort: Medium**

"Hey Siri, start Chinese practice" — register an App Intent for starting a practice session. Low effort for a nice polish feature.

### 5e. Export/Import Progress
**Impact: Low | Effort: Low**

Let users export their review data as JSON/CSV for backup or analysis. Also useful for migrating between devices before iCloud sync is implemented.

---

## 6. Accessibility

### 6a. VoiceOver Support
**Impact: High | Effort: Medium**

Audit and add proper VoiceOver labels throughout the app. The PencilKit canvas interaction would need custom accessibility actions. Stroke order animation should have audio descriptions.

### 6b. Dynamic Type
**Impact: Medium | Effort: Low**

Ensure all text scales properly with Dynamic Type settings. Most SwiftUI text should handle this automatically, but the fixed canvas sizes and custom font sizes need attention.

### 6c. Localization
**Impact: Medium | Effort: Medium**

The app UI is English-only. Localize into at least: Simplified Chinese (for heritage learners), Japanese (kanji learners), Korean (hanja learners). The character data itself doesn't need localization, but all UI strings do.

---

## Recommended Priority Order

**Quick wins (high impact, low effort):**
1. Undo last stroke (2c)
2. Stroke count display (1c)
3. Animation speed control (4d)
4. Session configuration (2b)

**High-value medium effort:**
5. Character search & browse (1a)
6. Onboarding flow (2a)
7. iCloud sync (5c)
8. Review forecast/heatmap (3a)

**Longer-term investments:**
9. Wrong stroke highlighting (1d)
10. VoiceOver support (6a)
11. Radical/component breakdown (1b)
12. iOS widget (5b)
