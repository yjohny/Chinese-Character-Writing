import SwiftUI

/// Shows a celebration animation (particles) when the user gets a character correct.
struct CelebrationView: View {
    @Binding var isActive: Bool

    @State private var particles: [Particle] = []
    @State private var viewSize: CGSize = .zero
    @State private var cleanupTask: Task<Void, Never>?

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var size: CGFloat
        var opacity: Double
        var rotation: Double
    }

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear { viewSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in viewSize = newSize }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                launchConfetti()
            }
        }
    }

    private func launchConfetti() {
        let centerX = viewSize.width / 2
        let startY = viewSize.height / 2

        var newParticles: [Particle] = []
        for _ in 0..<40 {
            newParticles.append(Particle(
                x: centerX + CGFloat.random(in: -20...20),
                y: startY,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...14),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            ))
        }

        particles = newParticles

        // Animate particles outward
        withAnimation(.easeOut(duration: 1.2)) {
            particles = particles.map { p in
                var p = p
                p.x += CGFloat.random(in: -200...200)
                p.y += CGFloat.random(in: -400...100)
                p.opacity = 0
                p.rotation += Double.random(in: -180...180)
                return p
            }
        }

        // Clean up — cancel previous cleanup if re-triggered
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            particles = []
            isActive = false
        }
    }
}
