import SwiftUI

struct HydrationScreen: View {
    let onComplete: (Int) -> Void

    @State private var fillProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var t: Double = 0
    @State private var showingHint = true

    private var waterTargetMl: Int {
        let raw = 1500 + Double(fillProgress) * 2000
        return Int((raw / 100).rounded()) * 100
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("HYDRATION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.hydrationColor)
                Text("Hold the glass")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("One tap. Total hydration.")
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            .padding(.top, 60)

            Spacer()

            FluidGlass(progress: fillProgress, t: t, isHolding: isHolding)
                .frame(width: 220, height: 300)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding {
                                isHolding = true
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                            }
                            withAnimation(.linear(duration: 0.1)) {
                                fillProgress = min(1, fillProgress + 0.012)
                            }
                            if showingHint {
                                withAnimation { showingHint = false }
                            }
                        }
                        .onEnded { _ in
                            isHolding = false
                            if fillProgress >= 0.95 {
                                let gen = UINotificationFeedbackGenerator()
                                gen.notificationOccurred(.success)
                            }
                        }
                )

            VStack(spacing: 6) {
                Text("\(waterTargetMl) ml")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .contentTransition(.numericText(value: Double(waterTargetMl)))
                Text(showingHint ? "Press and hold to set your daily target" : (fillProgress >= 0.95 ? "Maxed out — tap Next to continue" : "Keep holding to raise your goal…"))
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 14) {
                PearlescentButton(action: {
                    onComplete(waterTargetMl)
                }) {
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .opacity(fillProgress > 0 ? 1 : 0.55)
                .disabled(fillProgress <= 0)
                .padding(.horizontal, 32)

                Button {
                    onComplete(2400)
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }
}

struct FluidGlass: View {
    var progress: CGFloat
    var t: Double
    var isHolding: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GlassShape()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        GlassShape().stroke(PrecisionCalTheme.glassStroke, lineWidth: 2)
                    }

                GlassShape()
                    .fill(.clear)
                    .overlay {
                        WaterFill(progress: progress, t: t)
                            .fill(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.hydrationColor.opacity(0.95), PrecisionCalTheme.sageLight.opacity(0.85)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .clipShape(GlassShape())

                GlassShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.85), PrecisionCalTheme.glassStroke],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )

                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 8, height: 60)
                    .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.2)
                    .blur(radius: 1)
            }
            .scaleEffect(isHolding ? 1.02 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHolding)
        }
    }
}

struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topInset: CGFloat = rect.width * 0.05
        let bottomInset: CGFloat = rect.width * 0.18
        p.move(to: CGPoint(x: topInset, y: 0))
        p.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: rect.width - bottomInset, y: rect.height),
            control: CGPoint(x: rect.width - topInset - 4, y: rect.height * 0.6)
        )
        p.addLine(to: CGPoint(x: bottomInset, y: rect.height))
        p.addQuadCurve(
            to: CGPoint(x: topInset, y: 0),
            control: CGPoint(x: topInset + 4, y: rect.height * 0.6)
        )
        return p
    }
}

struct WaterFill: Shape {
    var progress: CGFloat
    var t: Double

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(progress, t) }
        set { progress = newValue.first; t = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let waterTop = rect.height * (1 - progress)
        let amplitude: CGFloat = max(0, min(8, progress * 12))
        let wavelength: CGFloat = rect.width / 1.2

        p.move(to: CGPoint(x: 0, y: waterTop))
        var x: CGFloat = 0
        while x <= rect.width {
            let relative = x / wavelength
            let y = waterTop + sin(relative * .pi * 2 + t) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}
