import SwiftUI

/// Generative 3-layer bloom that breathes with the user's day.
/// - Inner petals  → Hydration progress
/// - Middle petals → Macros progress (avg of calories/protein/carbs/fat)
/// - Outer glow    → PhD Protocol adherence (overall day score)
struct VitalityBloom: View {
    let hydration: Double      // 0...1
    let macros: Double         // 0...1
    let adherence: Double      // 0...1
    var size: CGFloat = 240

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                outerGlow(t: t)
                petals(layer: 1, count: 12, t: t,
                       progress: macros,
                       baseRadius: size * 0.34,
                       reach: size * 0.16,
                       color: PrecisionCalTheme.carbColor,
                       speed: 0.55,
                       phase: 0.0)
                petals(layer: 0, count: 8, t: t,
                       progress: hydration,
                       baseRadius: size * 0.20,
                       reach: size * 0.12,
                       color: PrecisionCalTheme.hydrationColor,
                       speed: 0.85,
                       phase: 0.6)
                core(t: t)
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Layers

    private func petals(layer: Int, count: Int, t: TimeInterval,
                        progress: Double,
                        baseRadius: CGFloat, reach: CGFloat,
                        color: Color, speed: Double, phase: Double) -> some View {
        let p = max(0, min(1, progress))
        let breath = (sin(t * speed) + 1) / 2  // 0...1
        let petalLen = baseRadius + reach * CGFloat(p) * (0.85 + 0.15 * CGFloat(breath))

        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = (Double(i) / Double(count)) * 360.0
                let wobble = sin(t * speed + Double(i) * 0.7 + phase) * 0.06
                let petalScale = 0.55 + 0.45 * p
                Petal(width: size * 0.18 * CGFloat(petalScale),
                      height: petalLen,
                      colors: [color.opacity(0.55), color.opacity(0.18)])
                    .rotationEffect(.degrees(angle + wobble * 30))
                    .offset(y: -petalLen / 2)
                    .blendMode(layer == 0 ? .normal : .plusLighter)
            }
        }
        .opacity(0.85)
    }

    private func outerGlow(t: TimeInterval) -> some View {
        let breath = (sin(t * 0.4) + 1) / 2
        let intensity = 0.25 + 0.55 * adherence
        let scale = 1.0 + 0.06 * CGFloat(breath)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        PrecisionCalTheme.terracotta.opacity(intensity * 0.55),
                        PrecisionCalTheme.terracotta.opacity(intensity * 0.20),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.18,
                    endRadius: size * 0.55
                )
            )
            .blur(radius: 14)
            .scaleEffect(scale)
            .allowsHitTesting(false)
    }

    private func core(t: TimeInterval) -> some View {
        let breath = (sin(t * 0.7) + 1) / 2
        let scale = 1.0 + 0.04 * CGFloat(breath)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95),
                                 PrecisionCalTheme.parchment.opacity(0.85),
                                 PrecisionCalTheme.terracotta.opacity(0.18)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.22, height: size * 0.22)
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.25), radius: 12)
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .scaleEffect(scale)
    }
}

private struct Petal: View {
    let width: CGFloat
    let height: CGFloat
    let colors: [Color]

    var body: some View {
        PetalShape()
            .fill(
                LinearGradient(colors: colors,
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: width, height: height)
            .overlay(
                PetalShape()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.7)
                    .frame(width: width, height: height)
            )
    }
}

private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: h),
                       control: CGPoint(x: w * 1.15, y: h * 0.45))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: 0),
                       control: CGPoint(x: -w * 0.15, y: h * 0.45))
        p.closeSubpath()
        return p
    }
}
