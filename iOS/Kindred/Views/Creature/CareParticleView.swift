import SwiftUI

/// Particle fan that bursts upward from the button center.
/// Increment `trigger` to fire a burst. Entirely view-layer — no engine changes.
struct ParticleBurst: View {
    let symbol: String
    let color: Color
    let trigger: Int

    // Fixed spread angles (upper semicircle, slight asymmetry so it feels organic)
    private static let angles: [Double]   = [-155, -125, -95, -65, -35, -170]
    private static let distances: [CGFloat] = [44, 52, 50, 48, 42, 38]
    private static let count = 6

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                let rad  = Self.angles[i] * .pi / 180.0
                let dist = Self.distances[i]
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .offset(
                        x: CGFloat(cos(rad)) * dist * phase,
                        y: CGFloat(sin(rad)) * dist * phase
                    )
                    .opacity(max(0, 1.0 - Double(phase) * 1.35))
                    .scaleEffect(0.65 + (1 - phase) * 0.5)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, new in
            guard new > 0 else { return }
            phase = 0
            withAnimation(.easeOut(duration: 0.62)) { phase = 1 }
        }
    }
}
