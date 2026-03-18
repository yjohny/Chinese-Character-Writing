import SwiftUI

/// Full-screen overlay celebrating a milestone achievement.
struct MilestoneView: View {
    let milestone: MilestoneType
    let onDismiss: () -> Void

    @State private var particles: [MilestoneParticle] = []
    @State private var showContent = false
    @State private var dismissTask: Task<Void, Never>?

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Confetti
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }

            // Content
            VStack(spacing: 20) {
                Image(systemName: milestone.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 10)

                Text(milestone.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(milestone.subtitle)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1.0 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone achieved: \(milestone.title). \(milestone.subtitle)")
        .accessibilityAddTraits(.isModal)
        .onTapGesture {
            dismiss()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            launchConfetti()

            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        onDismiss()
    }

    private func launchConfetti() {
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let screenHeight: CGFloat = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2

        var newParticles: [MilestoneParticle] = []
        for _ in 0..<80 {
            newParticles.append(MilestoneParticle(
                x: centerX + CGFloat.random(in: -20...20),
                y: centerY,
                color: colors.randomElement() ?? .orange,
                size: CGFloat.random(in: 6...14),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            ))
        }
        particles = newParticles

        withAnimation(.easeOut(duration: 1.5)) {
            particles = particles.map { p in
                var p = p
                p.x += CGFloat.random(in: -250...250)
                p.y += CGFloat.random(in: -500...200)
                p.opacity = 0
                p.rotation += Double.random(in: -180...180)
                return p
            }
        }
    }
}

private struct MilestoneParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var opacity: Double
    var rotation: Double
}
