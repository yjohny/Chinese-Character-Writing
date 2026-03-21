import SwiftUI
import PencilKit

/// Main practice view. Switches between sub-views based on StudyState.
/// Auto-starts on appear for drop-in practice. Users can stop anytime via "Done".
struct PracticeView: View {
    @Bindable var viewModel: PracticeViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    /// Brief "Resuming session" toast shown when the user returns to the Practice tab
    /// while a session is already in progress.
    @State private var showResumeIndicator = false

    /// Tracks whether the view has appeared at least once (to distinguish first launch
    /// from tab switching).
    @State private var hasAppearedBefore = false

    /// Canvas size adapts to iPad vs iPhone.
    private var canvasSize: CGFloat {
        sizeClass == .regular ? 420 : 300
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.studyState)

                // Celebration overlay
                CelebrationView(isActive: $viewModel.showCelebration)

                // Daily goal completion overlay
                if viewModel.showDailyGoalComplete {
                    dailyGoalOverlay
                }

                // Milestone celebration overlay
                if let milestone = viewModel.activeMilestone {
                    MilestoneView(milestone: milestone) {
                        viewModel.activeMilestone = nil
                    }
                }

                // Session resume indicator
                if showResumeIndicator {
                    VStack {
                        Text("Resuming session")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }

                // Floating buttons
                if showFloatingButtons {
                    VStack {
                        Spacer()
                        HStack {
                            if viewModel.studyState == .writing {
                                Button(action: { viewModel.skipAsUnknown() }) {
                                    Label("Show me", systemImage: "eye")
                                        .font(.callout)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                .padding()
                                .accessibilityHint("Skip to stroke order review if you don't know this character")
                            }

                            Spacer()

                            if showOverrideButton {
                                Button(action: { viewModel.overrideCorrect() }) {
                                    Label("I got it right", systemImage: "checkmark.circle")
                                        .font(.callout)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                                .padding()
                                .accessibilityHint("Override if your handwriting was correct but not recognized")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isActivelyPracticing {
                    ToolbarItem(placement: .topBarLeading) {
                        let progress = viewModel.sessionManager.dailyProgress()
                        DailyProgressRing(current: progress.current, goal: progress.goal)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            viewModel.endPractice()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.canvasSize = canvasSize
                if hasAppearedBefore && isActivelyPracticing {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showResumeIndicator = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showResumeIndicator = false
                        }
                    }
                }
                hasAppearedBefore = true
                viewModel.beginIfNeeded()
            }
            .onChange(of: sizeClass) { _, _ in
                viewModel.canvasSize = canvasSize
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.handleReturnToForeground()
                }
            }
        }
    }

    /// Whether any floating button should be visible.
    private var showFloatingButtons: Bool {
        viewModel.studyState == .writing || showOverrideButton
    }

    /// "I got it right" only appears after the user has submitted their writing
    /// (recognizing/incorrect) and drawn enough strokes to indicate a real attempt.
    /// During rewriting, it also appears after a failed recognition attempt or
    /// while recognition is running, so users aren't trapped by misrecognition.
    private var showOverrideButton: Bool {
        if (viewModel.studyState == .recognizing || viewModel.studyState == .incorrect)
            && viewModel.hasDrawnEnoughForOverride {
            return true
        }
        if viewModel.studyState == .rewriting
            && (viewModel.rewriteAttempts >= 1 || viewModel.isRecognizing) {
            return true
        }
        return false
    }

    @ViewBuilder
    private var dailyGoalOverlay: some View {
        DailyGoalOverlayView(isShowing: $viewModel.showDailyGoalComplete)
    }

    /// Whether the user is in an active practice flow (not idle or complete).
    private var isActivelyPracticing: Bool {
        switch viewModel.studyState {
        case .idle, .sessionComplete:
            return false
        default:
            return true
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.studyState {
        case .idle:
            idleView

        case .presenting, .writing:
            writingView

        case .recognizing:
            writingView
                .overlay {
                    ProgressView("Recognizing...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

        case .correct:
            correctView

        case .incorrect:
            incorrectView

        case .showingStrokeOrder:
            strokeOrderView

        case .tracing:
            tracingView

        case .rewriting:
            rewritingView

        case .sessionComplete:
            practiceCompleteView
        }
    }

    // MARK: - Sub-views

    private var idleView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var writingView: some View {
        AdaptiveLayout(sizeClass: sizeClass) {
            VStack(spacing: 12) {
                if let entry = viewModel.currentEntry {
                    CharacterPromptView(
                        entry: entry,
                        useTraditional: viewModel.useTraditional,
                        onTTSTap: { viewModel.playTTS() }
                    )
                }

                HStack(spacing: 4) {
                    Text("Write the character")
                    if let strokeData = viewModel.currentStrokeData {
                        Text("(\(strokeData.strokes.count) strokes)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.8)
            }
        } canvas: {
            VStack(spacing: 16) {
                WritingCanvasContainer(
                    drawing: $viewModel.writingDrawing,
                    onSubmit: { viewModel.submitWriting() },
                    onUndoAvailabilityChanged: { viewModel.canUndo = $0 },
                    size: canvasSize
                )

                HStack(spacing: 16) {
                    Button(action: { viewModel.undoLastStroke() }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canUndo)

                    Button(action: { viewModel.clearCanvas() }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { viewModel.submitWriting() }) {
                        Label("Check", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.writingDrawing.strokes.isEmpty)
                }
            }
        }
        .padding()
    }

    private var correctView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.displayCharacter(traditional: viewModel.useTraditional))
                    .font(.custom("STKaiti", size: sizeClass == .regular ? 160 : 120))
                    .accessibilityLabel("Character: \(entry.displayCharacter(traditional: viewModel.useTraditional)), \(entry.pinyin)")

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("Correct!")
                    .font(.title2)
                    .foregroundStyle(.green)

                if viewModel.currentStrokeData != nil {
                    Button(action: { viewModel.reviewStrokeOrder() }) {
                        Label("Review Strokes", systemImage: "hand.draw")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .accessibilityHint("Watch the stroke order animation for this character")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var incorrectView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.displayCharacter(traditional: viewModel.useTraditional))
                    .font(.custom("STKaiti", size: sizeClass == .regular ? 140 : 100))
                    .accessibilityLabel("Character: \(entry.displayCharacter(traditional: viewModel.useTraditional)), \(entry.pinyin)")

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("Let's practice the strokes!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var strokeOrderView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let strokeData = viewModel.currentStrokeData {
                StrokeOrderView(
                    strokeData: strokeData,
                    onComplete: { viewModel.strokeOrderComplete() },
                    size: canvasSize - 20,
                    animationSpeed: viewModel.animationSpeed
                )
            }
        }
        .padding()
    }

    private var tracingView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let strokeData = viewModel.currentStrokeData {
                TracingCanvasView(
                    strokeData: strokeData,
                    drawing: $viewModel.tracingDrawing,
                    onComplete: { viewModel.tracingComplete() },
                    size: canvasSize
                )
            }

            HStack(spacing: 16) {
                Button(action: { viewModel.undoLastStroke() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canUndo)

                Button(action: { viewModel.clearCanvas() }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button(action: { viewModel.tracingComplete() }) {
                    Label("Done Tracing", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var rewritingView: some View {
        AdaptiveLayout(sizeClass: sizeClass) {
            VStack(spacing: 12) {
                if let entry = viewModel.currentEntry {
                    CharacterPromptView(
                        entry: entry,
                        useTraditional: viewModel.useTraditional,
                        onTTSTap: { viewModel.playTTS() }
                    )
                }

                Text("Now write it from memory")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                if let feedback = viewModel.rewriteFeedback {
                    Text(feedback)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        } canvas: {
            VStack(spacing: 16) {
                WritingCanvasContainer(
                    drawing: $viewModel.rewriteDrawing,
                    onSubmit: { viewModel.submitRewrite() },
                    onUndoAvailabilityChanged: { viewModel.canUndo = $0 },
                    size: canvasSize
                )

                if viewModel.isRecognizing {
                    ProgressView("Checking...")
                        .font(.caption)
                } else {
                    HStack(spacing: 16) {
                        Button(action: { viewModel.undoLastStroke() }) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.canUndo)

                        Button(action: { viewModel.clearCanvas() }) {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { viewModel.submitRewrite() }) {
                            Label("Check", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.rewriteDrawing.strokes.isEmpty)
                    }

                    if viewModel.rewriteAttempts >= 2 && viewModel.currentStrokeData != nil {
                        Button(action: { viewModel.showStrokesAgain() }) {
                            Label("Show strokes again", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
        }
        .padding()
    }

    private var practiceCompleteView: some View {
        VStack(spacing: 24) {
            if viewModel.totalCount > 0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                Text("Nice work!")
                    .font(.title)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Correct: \(viewModel.correctCount)")
                    }
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text("Needed practice: \(viewModel.incorrectCount)")
                    }
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        Text("Total: \(viewModel.totalCount)")
                    }
                }
                .font(.title3)
                .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("All caught up!")
                    .font(.title)

                Text("No characters to review right now.\nNew characters will be added each day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { viewModel.practiceMore() }) {
                Label("Practice More", systemImage: "arrow.clockwise")
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Daily Goal Overlay

/// Extracted so we can store and cancel the auto-dismiss Task properly.
private struct DailyGoalOverlayView: View {
    @Binding var isShowing: Bool
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Daily goal complete!")
                .font(.title2.bold())
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily goal complete!")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            dismissTask?.cancel()
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                withAnimation { isShowing = false }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }
}

// MARK: - Adaptive Layout

/// Switches between VStack (iPhone) and HStack (iPad) for prompt + canvas pairs.
private struct AdaptiveLayout<Prompt: View, Canvas: View>: View {
    let sizeClass: UserInterfaceSizeClass?
    @ViewBuilder let prompt: () -> Prompt
    @ViewBuilder let canvas: () -> Canvas

    var body: some View {
        if sizeClass == .regular {
            HStack(spacing: 32) {
                prompt()
                    .frame(maxWidth: .infinity)
                canvas()
            }
        } else {
            VStack(spacing: 16) {
                prompt()
                canvas()
            }
        }
    }
}
