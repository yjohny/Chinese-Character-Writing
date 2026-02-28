import SwiftUI
import PencilKit

/// Main practice view. Switches between sub-views based on StudyState.
/// Auto-starts on appear for drop-in practice. Users can stop anytime via "Done".
struct PracticeView: View {
    @Bindable var viewModel: PracticeViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    /// Canvas size adapts to iPad vs iPhone.
    private var canvasSize: CGFloat {
        sizeClass == .regular ? 420 : 300
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                    .animation(.easeInOut(duration: 0.3), value: viewModel.studyState)

                // Celebration overlay
                CelebrationView(isActive: $viewModel.showCelebration)

                // Override button (floating, visible during writing/recognizing)
                if showOverrideButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { viewModel.overrideCorrect() }) {
                                Label("I got it right", systemImage: "checkmark.circle")
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isActivelyPracticing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            viewModel.endPractice()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.canvasSize = canvasSize
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

    private var showOverrideButton: Bool {
        viewModel.studyState == .writing || viewModel.studyState == .recognizing
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

                Text("Write the character")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } canvas: {
            VStack(spacing: 16) {
                WritingCanvasContainer(
                    drawing: $viewModel.writingDrawing,
                    onSubmit: { viewModel.submitWriting() },
                    size: canvasSize
                )

                HStack(spacing: 16) {
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

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Correct!")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var incorrectView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.displayCharacter(traditional: viewModel.useTraditional))
                    .font(.custom("STKaiti", size: sizeClass == .regular ? 140 : 100))

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text("Let's practice the strokes!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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
                    size: canvasSize - 20
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
                    size: canvasSize
                )

                if viewModel.isRecognizing {
                    ProgressView("Checking...")
                        .font(.caption)
                } else {
                    HStack(spacing: 16) {
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

                Text("Nice work!")
                    .font(.title)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Correct: \(viewModel.correctCount)")
                    }
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Reviewed: \(viewModel.incorrectCount)")
                    }
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Total: \(viewModel.totalCount)")
                    }
                }
                .font(.title3)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

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

            Button(action: { viewModel.endPractice() }) {
                Text("Done")
                    .font(.body)
            }
            .buttonStyle(.bordered)
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
