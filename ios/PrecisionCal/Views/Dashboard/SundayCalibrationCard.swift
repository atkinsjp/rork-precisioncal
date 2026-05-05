import SwiftUI

/// Warm Sanctuary notification revealing this week's three Protocol Pivots
/// from the Senior PhD Clinical Nutritionist persona.
struct SundayCalibrationCard: View {
    let calibration: Calibration
    var onAcknowledge: () -> Void = {}

    @State private var expanded: Bool = true
    @State private var revealed: Set<Int> = []
    @State private var pressed: Bool = false

    private var pivots: [(title: String, body: String)] {
        zip(calibration.pivotTitles, calibration.pivotBodies).map { ($0, $1) }
    }

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: calibration.weekStart)) – \(f.string(from: calibration.weekEnd))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !calibration.summary.isEmpty {
                Text(calibration.summary)
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            if expanded {
                VStack(spacing: 10) {
                    ForEach(Array(pivots.enumerated()), id: \.offset) { idx, pair in
                        PivotRow(
                            index: idx + 1,
                            title: pair.title,
                            text: pair.body,
                            visible: revealed.contains(idx)
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            HStack(spacing: 12) {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        expanded.toggle()
                    }
                } label: {
                    Text(expanded ? "Collapse" : "Show pivots")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background {
                            Capsule().stroke(PrecisionCalTheme.terracotta.opacity(0.4), lineWidth: 1)
                        }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onAcknowledge()
                } label: {
                    Text("Begin the week")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 16)
                        .background {
                            Capsule().fill(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: PrecisionCalTheme.terracotta.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    PrecisionCalTheme.terracotta.opacity(0.45),
                                    PrecisionCalTheme.glassStroke,
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.10), radius: 18, x: 0, y: 10)
        }
        .scaleEffect(pressed ? 0.99 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pressed)
        .onAppear {
            // Stagger-reveal each pivot for a 'materialize' feel.
            for idx in pivots.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(idx) * 0.18) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        _ = revealed.insert(idx)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(PrecisionCalTheme.terracotta.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                    .symbolEffect(.pulse, options: .repeating)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("SUNDAY CALIBRATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("Protocol Pivot · \(dateRange)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            Spacer()
        }
    }
}

private struct PivotRow: View {
    let index: Int
    let title: String
    let text: String
    let visible: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.terracotta)
                .frame(width: 26, height: 26)
                .background {
                    Circle()
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.55), lineWidth: 1.2)
                        .background(Circle().fill(Color.white.opacity(0.6)))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.5), lineWidth: 1)
                }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 6)
        .blur(radius: visible ? 0 : 2)
    }
}
