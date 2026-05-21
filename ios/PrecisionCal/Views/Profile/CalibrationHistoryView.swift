import SwiftUI
import SwiftData

/// Past Sunday Calibrations — a quiet archive of the user's protocol pivots.
struct CalibrationHistoryView: View {
    @Query(sort: \Calibration.createdAt, order: .reverse) private var calibrations: [Calibration]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if calibrations.isEmpty {
                    emptyState
                } else {
                    ForEach(calibrations) { cal in
                        CalibrationHistoryCard(calibration: cal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Calibrations")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ARCHIVE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Your protocol pivots")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Every Sunday, Cal reviews your week and suggests educational adjustments to your protocol.")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(PrecisionCalTheme.terracotta.opacity(0.7))
                .symbolEffect(.pulse, options: .repeating)
            Text("No calibrations yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Log meals through the week — your first protocol pivot arrives this Sunday.")
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct CalibrationHistoryCard: View {
    let calibration: Calibration
    @State private var expanded: Bool = false

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: calibration.weekStart)) – \(f.string(from: calibration.weekEnd))"
    }

    private var pivots: [(title: String, body: String)] {
        zip(calibration.pivotTitles, calibration.pivotBodies).map { ($0, $1) }
    }

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PrecisionCalTheme.terracotta.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateRange.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        Text(calibration.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }

                if !calibration.summary.isEmpty {
                    Text(calibration.summary)
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineSpacing(2)
                        .lineLimit(expanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if expanded {
                    VStack(spacing: 8) {
                        ForEach(Array(pivots.enumerated()), id: \.offset) { idx, pair in
                            HistoryPivotRow(index: idx + 1, title: pair.title, text: pair.body)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(PrecisionCalTheme.glassStroke.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.06), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryPivotRow: View {
    let index: Int
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.terracotta)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.55), lineWidth: 1.2)
                        .background(Circle().fill(Color.white.opacity(0.6)))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
