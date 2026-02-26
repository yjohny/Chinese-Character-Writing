import SwiftUI
import PencilKit

/// Main study session view. Switches between sub-views based on StudyState.
struct PracticeView: View {
    @Bindable var viewModel: PracticeViewModel

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
        }
    }

    private var showOverrideButton: Bool {
        viewModel.studyState == .writing || viewModel.studyState == .recognizing
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
            sessionCompleteView
        }
    }

    // MARK: - Sub-views

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Ready to Practice")
                .font(.title2)

            Button(action: { viewModel.startSession() }) {
                Label("Start", systemImage: "play.fill")
                    .font(.title3)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var writingView: some View {
        VStack(spacing: 16) {
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

            WritingCanvasContainer(
                drawing: $viewModel.writingDrawing,
                onSubmit: { viewModel.submitWriting() }
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
        .padding()
    }

    private var correctView: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                Text(entry.displayCharacter(traditional: viewModel.useTraditional))
                    .font(.custom("STKaiti", size: 120))

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
                    .font(.custom("STKaiti", size: 100))

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)

                if let recognized = viewModel.recognizedChar {
                    Text("Recognized: \(recognized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Let's review the strokes...")
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
                    onComplete: { viewModel.strokeOrderComplete() }
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
                    onComplete: { viewModel.tracingComplete() }
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
        VStack(spacing: 16) {
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

            WritingCanvasContainer(
                drawing: $viewModel.rewriteDrawing,
                onSubmit: { viewModel.submitRewrite() }
            )

            HStack(spacing: 16) {
                Button(action: { viewModel.clearCanvas() }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button(action: { viewModel.submitRewrite() }) {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.rewriteDrawing.strokes.isEmpty)
            }
        }
        .padding()
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Session Complete!")
                .font(.title)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Correct: \(viewModel.correctCount)")
                }
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(.orange)
                    Text("To Review: \(viewModel.incorrectCount)")
                }
                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Total: \(viewModel.totalCount)")
                }
            }
            .font(.title3)

            Button(action: { viewModel.startSession() }) {
                Label("Practice More", systemImage: "arrow.clockwise")
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            Button(action: { viewModel.studyState = .idle }) {
                Text("Done")
                    .font(.body)
            }
            .buttonStyle(.bordered)
        }
    }
}
