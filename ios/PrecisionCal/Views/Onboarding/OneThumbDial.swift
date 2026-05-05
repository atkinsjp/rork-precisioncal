import SwiftUI

struct OneThumbDial: View {
    let title: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var accessory: AnyView? = nil

    @State private var dragRotation: Double = 0
    @State private var lastTickValue: Double = .nan
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GlassCard {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                        if let accessory {
                            accessory
                        }
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(displayValue)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                            .contentTransition(.numericText(value: value))
                        Text(unit)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }
                Spacer()
                DialKnob(value: $value, range: range, step: step, haptic: haptic)
                    .frame(width: 96, height: 96)
            }
            .padding(20)
        }
    }

    private var displayValue: String {
        if step >= 1 { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }
}

private struct DialKnob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let haptic: UIImpactFeedbackGenerator

    @State private var startAngle: Angle = .zero
    @State private var startValue: Double = 0
    @State private var lastSnap: Double = .nan

    var body: some View {
        ZStack {
            Circle()
                .stroke(PrecisionCalTheme.glassStroke.opacity(0.5), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.fatColor, PrecisionCalTheme.terracotta], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(.ultraThinMaterial)
                .padding(16)
                .overlay {
                    Circle()
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
                        .padding(16)
                }

            Circle()
                .fill(PrecisionCalTheme.terracotta)
                .frame(width: 10, height: 10)
                .offset(y: -34)
                .rotationEffect(.degrees(progress * 360 - 180))
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let center = CGPoint(x: 48, y: 48)
                    let dx = v.location.x - center.x
                    let dy = v.location.y - center.y
                    let ang = atan2(dy, dx)
                    if startAngle == .zero {
                        startAngle = .radians(ang)
                        startValue = value
                    }
                    var delta = ang - startAngle.radians
                    if delta > .pi { delta -= 2 * .pi }
                    if delta < -.pi { delta += 2 * .pi }
                    let span = range.upperBound - range.lowerBound
                    let newValue = startValue + (delta / (2 * .pi)) * span * 1.4
                    let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                    let snapped = (clamped / step).rounded() * step
                    if snapped != lastSnap {
                        haptic.impactOccurred(intensity: 0.6)
                        lastSnap = snapped
                    }
                    withAnimation(.interactiveSpring()) {
                        value = snapped
                    }
                }
                .onEnded { _ in
                    startAngle = .zero
                }
        )
    }

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        return (value - range.lowerBound) / span
    }
}
