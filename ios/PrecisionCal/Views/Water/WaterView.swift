import SwiftUI
import SwiftData

struct WaterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \WaterEntry.createdAt, order: .reverse) private var entries: [WaterEntry]

    private var profile: UserProfile? { profiles.first }
    private var todayEntries: [WaterEntry] {
        entries.filter { Calendar.current.isDateInToday($0.createdAt) }
    }
    private var todayTotal: Double { todayEntries.reduce(0) { $0 + $1.amountMl } }
    private var target: Double { Double(profile?.dailyWaterTargetMl ?? 2400) }
    private var progress: Double { min(1, todayTotal / max(target, 1)) }

    @State private var t: Double = 0
    @State private var lastTapId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                FluidGlass(progress: CGFloat(progress), t: t, isHolding: false)
                    .frame(width: 220, height: 300)
                    .overlay {
                        VStack(spacing: 4) {
                            Text("\(Int(todayTotal))")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                                .contentTransition(.numericText(value: todayTotal))
                            Text("of \(Int(target)) ml")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                        }
                    }

                bubblesRow

                if !todayEntries.isEmpty {
                    todayLog
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HYDRATION")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.hydrationColor)
            Text("One tap")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var bubblesRow: some View {
        HStack(spacing: 14) {
            WaterBubbleButton(label: "8 oz", subtitle: "237 ml", ml: 237) { add($0) }
            WaterBubbleButton(label: "12 oz", subtitle: "355 ml", ml: 355) { add($0) }
            WaterBubbleButton(label: "16 oz", subtitle: "473 ml", ml: 473) { add($0) }
        }
    }

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S SIPS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.horizontal, 4)
            ForEach(todayEntries.prefix(6)) { entry in
                GlassCard(cornerRadius: 14) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(PrecisionCalTheme.hydrationColor)
                        Text("\(Int(entry.amountMl)) ml")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        Spacer()
                        Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                    .padding(14)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(entry)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    private func add(_ ml: Double) {
        let entry = WaterEntry(amountMl: ml)
        modelContext.insert(entry)
        try? modelContext.save()
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }
}

struct WaterBubbleButton: View {
    let label: String
    let subtitle: String
    let ml: Double
    let action: (Double) -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    pressed = false
                }
            }
            action(ml)
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PrecisionCalTheme.hydrationColor.opacity(0.45), PrecisionCalTheme.hydrationColor.opacity(0.0)],
                                center: .topLeading, startRadius: 4, endRadius: 110
                            )
                        )
                    Circle()
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)

                    Circle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .blur(radius: 2)
                        .offset(x: -22, y: -28)
                }
            }
            .clipShape(Circle())
            .scaleEffect(pressed ? 1.08 : 1)
        }
        .buttonStyle(.plain)
    }
}
