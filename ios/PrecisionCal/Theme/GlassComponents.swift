import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(PrecisionCalTheme.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.85), PrecisionCalTheme.glassStroke],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.06), radius: 20, x: 0, y: 8)
            }
    }
}

/// Primary terracotta button — Warm Sanctuary aesthetic.
struct PearlescentButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var isPressed = false
    @State private var ripples: [TapRipple] = []

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .soft)
            gen.impactOccurred()
            spawnRipple()
            action()
        } label: {
            label()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.35), radius: 18, x: 0, y: 10)
                }
                .overlay {
                    GeometryReader { geo in
                        Canvas { ctx, size in
                            for r in ripples {
                                let radius = r.progress * max(size.width, size.height) * 1.1
                                let opacity = (1 - r.progress) * 0.30
                                let rect = CGRect(
                                    x: size.width / 2 - radius,
                                    y: size.height / 2 - radius,
                                    width: radius * 2, height: radius * 2
                                )
                                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                            }
                        }
                        .allowsHitTesting(false)
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
    }

    private func spawnRipple() {
        let r = TapRipple()
        ripples.append(r)
        withAnimation(.easeOut(duration: 0.9)) {
            if let i = ripples.firstIndex(where: { $0.id == r.id }) {
                ripples[i].progress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll { $0.id == r.id }
        }
    }
}

struct TapRipple: Identifiable {
    let id = UUID()
    var progress: CGFloat = 0
}

struct PressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Breathing Orb (replaces ActivityIndicator)

/// Soft, warm 'breathing' orb. 60pt circle with 20% opacity blur,
/// scaling 1.0→1.2 every 2s easeInOut.
struct BreathingOrb: View {
    var size: CGFloat = 60
    var color: Color = PrecisionCalTheme.terracotta
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.20))
                .frame(width: size, height: size)
                .blur(radius: size * 0.18)

            Circle()
                .fill(color.opacity(0.55))
                .frame(width: size * 0.55, height: size * 0.55)
                .blur(radius: size * 0.08)

            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: size * 0.18, height: size * 0.18)
                .blur(radius: size * 0.04)
                .offset(x: -size * 0.08, y: -size * 0.08)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
        .accessibilityLabel("Loading")
    }
}

// MARK: - Gentle Wave ripple (white 30% opacity)

struct RippleModifier: ViewModifier {
    @State private var ripples: [Ripple] = []

    struct Ripple: Identifiable {
        let id = UUID()
        let center: CGPoint
        var progress: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                Canvas { ctx, size in
                    for ripple in ripples {
                        let radius = ripple.progress * max(size.width, size.height) * 0.9
                        let opacity = (1 - ripple.progress) * 0.30
                        let rect = CGRect(
                            x: ripple.center.x - radius,
                            y: ripple.center.y - radius,
                            width: radius * 2, height: radius * 2
                        )
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in addRipple(at: value.location) }
            )
    }

    private func addRipple(at point: CGPoint) {
        let ripple = Ripple(center: point)
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.9)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].progress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

extension View {
    func gentleWaveRipple() -> some View {
        modifier(RippleModifier())
    }
}
