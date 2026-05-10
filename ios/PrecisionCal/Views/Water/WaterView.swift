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
    @State private var showManualLog = false
    @State private var editingEntry: WaterEntry?
    @State private var pendingDelete: WaterEntry?

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

                manualLogButton

                if !todayEntries.isEmpty {
                    todayLog
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showManualLog) {
            ManualWaterLogSheet(existing: nil) { ml, date in
                let entry = WaterEntry(createdAt: date, amountMl: ml)
                modelContext.insert(entry)
                try? modelContext.save()
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingEntry) { entry in
            ManualWaterLogSheet(existing: entry) { ml, date in
                entry.amountMl = ml
                entry.createdAt = date
                try? modelContext.save()
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { entry in
            Text("\(Int(entry.amountMl)) ml at \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
        }
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

    private var manualLogButton: some View {
        Button {
            showManualLog = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log manually")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(PrecisionCalTheme.hydrationColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S SIPS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.horizontal, 4)
            ForEach(todayEntries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    GlassCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(PrecisionCalTheme.hydrationColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(entry.amountMl)) ml")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                                .padding(.trailing, 4)
                            Button {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                pendingDelete = entry
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 32, height: 32)
                                    .background(Color.red.opacity(0.12), in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingEntry = entry
                    } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) {
                        pendingDelete = entry
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

struct ManualWaterLogSheet: View {
    let existing: WaterEntry?
    let onSave: (Double, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var unit: WaterUnit = .oz
    @State private var amountText: String = "8"
    @State private var date: Date = Date()
    @State private var didInit: Bool = false

    enum WaterUnit: String, CaseIterable, Identifiable {
        case oz = "oz"
        case ml = "ml"
        var id: String { rawValue }
    }

    private var amountMl: Double {
        let raw = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch unit {
        case .oz: return raw * 29.5735
        case .ml: return raw
        }
    }

    private var canSave: Bool { amountMl > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Picker("Unit", selection: $unit) {
                            ForEach(WaterUnit.allCases) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                    if amountMl > 0 {
                        Text("\(Int(amountMl)) ml")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("When") {
                    DatePicker("Date & time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    HStack(spacing: 10) {
                        ForEach([("8 oz", 8.0), ("12 oz", 12.0), ("16 oz", 16.0), ("20 oz", 20.0)], id: \.0) { item in
                            Button {
                                unit = .oz
                                amountText = item.1.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(item.1))" : "\(item.1)"
                            } label: {
                                Text(item.0)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(PrecisionCalTheme.hydrationColor.opacity(0.15), in: .rect(cornerRadius: 10))
                                    .foregroundStyle(PrecisionCalTheme.hydrationColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("Quick fill")
                }
            }
            .navigationTitle(existing == nil ? "Log Water" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !didInit else { return }
                didInit = true
                if let existing {
                    unit = .ml
                    let ml = existing.amountMl
                    amountText = ml.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(ml))" : String(format: "%.0f", ml)
                    date = existing.createdAt
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(amountMl, date)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
