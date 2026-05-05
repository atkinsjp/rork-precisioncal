import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @Query(sort: \Calibration.createdAt, order: .reverse) private var calibrations: [Calibration]
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    @State private var calibrating: Bool = false
    @State private var calibrationToast: String? = nil

    private var profile: UserProfile? { profiles.first }

    private var weekMealCount: Int {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return meals.filter { $0.createdAt >= weekStart && $0.status == "complete" }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let profile {
                        profileCard(profile)
                        targetsCard(profile)
                    }

                    calibrationCard

                    resetCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .calibrationHistory:
                    CalibrationHistoryView()
                }
            }
            .overlay(alignment: .top) {
                if let toast = calibrationToast {
                    ToastBanner(text: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROFILE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Your calibration")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private func profileCard(_ p: UserProfile) -> some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.fatColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 64, height: 64)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.goal)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        Text("\(p.ageYears) yrs • \(Int(p.weightKg)) kg")
                            .font(.system(size: 13))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                    }
                    Spacer()
                }
            }
            .padding(20)
        }
    }

    private func targetsCard(_ p: UserProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DAILY TARGETS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)

                TargetRow(icon: "flame.fill", color: PrecisionCalTheme.proteinColor, label: "Calories", value: "\(p.dailyCalorieTarget) kcal")
                TargetRow(icon: "bolt.fill", color: PrecisionCalTheme.proteinColor, label: "Protein", value: "\(p.dailyProteinTarget) g")
                TargetRow(icon: "leaf.fill", color: PrecisionCalTheme.carbColor, label: "Carbs", value: "\(p.dailyCarbTarget) g")
                TargetRow(icon: "drop.halffull", color: PrecisionCalTheme.fatColor, label: "Fat", value: "\(p.dailyFatTarget) g")
                TargetRow(icon: "drop.fill", color: PrecisionCalTheme.hydrationColor, label: "Water", value: "\(p.dailyWaterTargetMl) ml")
            }
            .padding(20)
        }
    }

    private var calibrationCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PrecisionCalTheme.terracotta.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .symbolEffect(.pulse, options: .repeating)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUNDAY CALIBRATION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                    Text(calibrations.isEmpty
                         ? "No calibrations yet"
                         : "\(calibrations.count) protocol pivot\(calibrations.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Spacer()
            }

            Button {
                Task { await runCalibration() }
            } label: {
                HStack(spacing: 10) {
                    if calibrating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(calibrating ? "Recalibrating…" : "Re-run calibration")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
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
            .buttonStyle(.plain)
            .disabled(calibrating || profile == nil || weekMealCount < 3)
            .opacity((profile == nil || weekMealCount < 3) ? 0.5 : 1)

            if weekMealCount < 3 && !calibrating {
                Text("Log at least 3 meals this week to recalibrate.")
                    .font(.system(size: 11))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink(value: ProfileRoute.calibrationHistory) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("View past calibrations")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                .foregroundStyle(PrecisionCalTheme.terracotta)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background {
                    Capsule().stroke(PrecisionCalTheme.terracotta.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.08), radius: 14, x: 0, y: 8)
        }
    }

    private var resetCard: some View {
        Button {
            for p in profiles { modelContext.delete(p) }
            try? modelContext.save()
            hasOnboarded = false
        } label: {
            GlassCard(cornerRadius: 18) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(PrecisionCalTheme.proteinColor)
                    Text("Restart calibration")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Spacer()
                }
                .padding(18)
            }
        }
        .buttonStyle(.plain)
    }

    private func runCalibration() async {
        guard !calibrating else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        calibrating = true
        let inserted = await SundayCalibrationService.shared.runManually(
            context: modelContext,
            profile: profile,
            recentMeals: meals
        )
        calibrating = false
        let message = inserted
            ? "New protocol pivot ready."
            : "Couldn't generate — try again later."
        withAnimation(.easeInOut(duration: 0.5)) {
            calibrationToast = message
        }
        if inserted {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        try? await Task.sleep(for: .seconds(2.4))
        withAnimation(.easeInOut(duration: 0.5)) {
            calibrationToast = nil
        }
    }
}

enum ProfileRoute: Hashable {
    case calibrationHistory
}

private struct ToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PrecisionCalTheme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().stroke(PrecisionCalTheme.terracotta.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.15), radius: 12, x: 0, y: 6)
            }
    }
}

struct TargetRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
    }
}
