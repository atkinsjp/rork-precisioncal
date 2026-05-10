import SwiftUI
import SwiftData
import PhotosUI

struct MealLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreViewModel.self) private var store
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]

    @State private var showCapture = false
    @State private var showManualEntry = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var activeMeal: Meal?
    @State private var quickItems: [String] = []
    @State private var currentPass: Int = 1
    @State private var error: String?
    @State private var showPaywall: Bool = false
    @State private var editingMeal: Meal?

    private var canScan: Bool { EntitlementGate.canScanMeal(isPremium: store.isPremium) }
    private var scansRemaining: Int { EntitlementGate.mealScansRemaining(isPremium: store.isPremium) }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    captureCard

                    if !meals.isEmpty {
                        Text("History")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        ForEach(meals) { meal in
                            Button {
                                quickItems = []
                                currentPass = 4
                                activeMeal = meal
                            } label: {
                                MealRow(meal: meal)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingMeal = meal
                                } label: { Label("Edit", systemImage: "square.and.pencil") }
                                Button(role: .destructive) {
                                    modelContext.delete(meal)
                                    try? modelContext.save()
                                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
        }
        .photosPicker(isPresented: $showCapture, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .sheet(isPresented: $showManualEntry) {
            ManualMealEntryView()
                .presentationDetents([.large])
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAndAnalyze(item: newItem) }
        }
        .sheet(item: $activeMeal) { meal in
            MealAnalysisSheet(meal: meal, quickItems: quickItems, currentPass: currentPass)
                .presentationDetents([.large])
                .presentationBackground(.clear)
        }
        .alert("Couldn't analyze", isPresented: .constant(error != nil), actions: {
            Button("OK") { error = nil }
        }, message: { Text(error ?? "") })
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .sheet(item: $editingMeal) { meal in
            EditMealView(meal: meal)
                .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MEALS")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Log a meal")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var captureCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PrecisionCalTheme.terracotta.opacity(0.4), PrecisionCalTheme.terracotta.opacity(0.0)],
                                center: .center, startRadius: 4, endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .symbolEffect(.pulse, options: .repeating)
                }

                Text("Snap a meal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("PrecisionCal sees ingredients, prep,\nportions, and lipid sheen in 5 passes.")
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                PearlescentButton(action: {
                    if canScan {
                        showCapture = true
                    } else {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showPaywall = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: canScan ? "photo.on.rectangle.angled" : "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(canScan ? "Choose photo" : "Unlock unlimited scans")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                }
                .padding(.horizontal, 8)

                if !store.isPremium {
                    Text(scansRemaining > 0
                         ? "\(scansRemaining) free AI scan\(scansRemaining == 1 ? "" : "s") left"
                         : "You've used your free AI scans.")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }

                Button {
                    showManualEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Log manually")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(PrecisionCalTheme.terracotta.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
    }

    @MainActor
    private func loadAndAnalyze(item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let image = UIImage(data: data) else { return }
        pickedImage = image
        await startAnalysis(imageData: data)
    }

    @MainActor
    private func startAnalysis(imageData: Data) async {
        guard canScan else {
            showPaywall = true
            return
        }
        EntitlementGate.recordMealScan()
        let meal = Meal(imageData: imageData, status: "analyzing")
        modelContext.insert(meal)
        try? modelContext.save()
        activeMeal = meal
        quickItems = []
        currentPass = 1
        isAnalyzing = true

        Task.detached(priority: .userInitiated) {
            do {
                let result = try await AIService.shared.analyzeChain(imageData: imageData) { event in
                    Task { @MainActor in
                        switch event {
                        case .pass1Identified(let items, let title):
                            quickItems = items
                            if meal.title.isEmpty { meal.title = title }
                            currentPass = 2
                        case .pass2Weighed:
                            currentPass = 3
                        case .pass3Mapped:
                            currentPass = 4
                        case .pass4Synthesized:
                            currentPass = 5
                        case .pass5LipidScanned:
                            break
                        }
                    }
                }
                await MainActor.run {
                    apply(result: result, to: meal)
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    meal.status = "failed"
                    meal.title = "Analysis failed"
                    meal.qcNotes = error.localizedDescription
                    try? modelContext.save()
                    self.error = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    @MainActor
    private func apply(result: MealAnalysisResult, to meal: Meal) {
        meal.title = result.title.isEmpty ? "Meal" : result.title
        meal.metabolicImpact = result.metabolicImpact
        meal.mealScore = result.mealScore
        meal.qcNotes = result.qcNotes
        meal.lipidSheenDetected = result.lipidSheenDetected
        meal.lipidNote = result.lipidNote
        meal.status = "complete"

        meal.items.removeAll()
        var totals = (cal: 0.0, p: 0.0, c: 0.0, f: 0.0, fb: 0.0, sg: 0.0, w: 0.0)
        for it in result.items {
            let item = MealItem(
                name: it.name,
                preparation: it.preparation,
                grams: it.grams,
                calories: it.calories,
                protein: it.protein,
                carbs: it.carbs,
                fat: it.fat,
                fiber: it.fiber,
                sugar: it.sugar,
                waterMl: it.waterMl
            )
            item.meal = meal
            meal.items.append(item)
            totals.cal += it.calories
            totals.p += it.protein
            totals.c += it.carbs
            totals.f += it.fat
            totals.fb += it.fiber
            totals.sg += it.sugar
            totals.w += it.waterMl
        }
        meal.totalCalories = totals.cal
        meal.totalProtein = totals.p
        meal.totalCarbs = totals.c
        meal.totalFat = totals.f
        meal.totalFiber = totals.fb
        meal.totalSugar = totals.sg
        meal.waterContentMl = totals.w
        try? modelContext.save()
    }
}
