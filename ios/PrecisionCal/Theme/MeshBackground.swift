import SwiftUI

/// Global Ambient Layer — a softly oscillating mesh gradient that lives behind
/// every screen. Movement is intentionally almost imperceptible (heat-haze /
/// slow-cloud feel) on a 20-second loop, to keep the environment soothing.
struct MeshBackground: View {
    var body: some View {
        ZStack {
            // Always-on linear base so iOS 17 / fallback still has the palette.
            LinearGradient(
                colors: [PrecisionCalTheme.bgTop, PrecisionCalTheme.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if #available(iOS 18.0, *) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    let phase = oscillation(at: context.date)
                    animatedMesh(phase: phase)
                        .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }

            warmBlobs
        }
    }

    /// Returns a value in [0, 1] that completes one full loop every 20 seconds.
    private func oscillation(at date: Date) -> CGFloat {
        let loop: TimeInterval = 20
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loop)
        return CGFloat(t / loop)
    }

    @available(iOS 18.0, *)
    private func animatedMesh(phase: CGFloat) -> some View {
        // Convert the 0...1 phase into a radian angle for sine-wave motion.
        let a = Float(phase) * .pi * 2
        // Tiny amplitudes — keep it subtle, like heat haze.
        let amp: Float = 0.04

        let p1: SIMD2<Float> = [0.0, 0.0]
        let p2: SIMD2<Float> = [0.5 + amp * 0.5 * sin(a),         0.0]
        let p3: SIMD2<Float> = [1.0, 0.0]
        let p4: SIMD2<Float> = [0.0, 0.5 + amp * sin(a * 0.9)]
        let p5: SIMD2<Float> = [0.5 + amp * cos(a * 0.7),         0.5 + amp * sin(a * 1.1)]
        let p6: SIMD2<Float> = [1.0, 0.5 - amp * sin(a * 0.8)]
        let p7: SIMD2<Float> = [0.0, 1.0]
        let p8: SIMD2<Float> = [0.5 - amp * 0.5 * cos(a),         1.0]
        let p9: SIMD2<Float> = [1.0, 1.0]

        // Specified palette: #F9F7F2, #EADFD3, with a hint of #D67D5B.
        let cream = Color(red: 0xF9 / 255, green: 0xF7 / 255, blue: 0xF2 / 255)
        let sand  = Color(red: 0xEA / 255, green: 0xDF / 255, blue: 0xD3 / 255)
        let terracottaHint = Color(red: 0xD6 / 255, green: 0x7D / 255, blue: 0x5B / 255)
            .opacity(0.18) // just a hint
        let terracottaWhisper = Color(red: 0xD6 / 255, green: 0x7D / 255, blue: 0x5B / 255)
            .opacity(0.08)

        let colors: [Color] = [
            cream,             cream,              sand,
            cream,             sand,               terracottaHint,
            sand,              terracottaWhisper,  cream,
        ]

        return MeshGradient(
            width: 3,
            height: 3,
            points: [p1, p2, p3, p4, p5, p6, p7, p8, p9],
            colors: colors,
            smoothsColors: true
        )
    }

    private var warmBlobs: some View {
        ZStack {
            Circle()
                .fill(PrecisionCalTheme.terracotta.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -130, y: -280)

            Circle()
                .fill(PrecisionCalTheme.fatColor.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 130)
                .offset(x: 150, y: 320)

            Circle()
                .fill(PrecisionCalTheme.sageLight.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 110)
                .offset(x: -160, y: 220)
        }
        .allowsHitTesting(false)
    }
}
