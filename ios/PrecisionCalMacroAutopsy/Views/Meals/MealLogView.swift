import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct MealLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreViewModel.self) private var store
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @Query(sort: \FavoriteMeal.createdAt, order: .reverse) private var favorites: [FavoriteMeal]

    @State private var showCapture = false
    @State private var showSourceDialog = false
    @State private var showCamera = false
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

    private var canScan: Bool { store.hasAccess }

    /// Discovery includes `.external` so an injected webcam is found in preview.
    private var cameraAvailable: Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .back
        )
        return !discovery.devices.isEmpty
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    captureCard

                    if !favorites.isEmpty {
                        favoritesSection
                    }

                    if !meals.isEmpty {
                        Text("History")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        ForEach(meals) { meal in
                            Button {
                                quickItems = []
                                currentPass = 6
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
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
            }
        }
        .photosPicker(isPresented: $showCapture, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .confirmationDialog("Snap a meal", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if cameraAvailable {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showCapture = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            MealCameraScreen(
                onCapture: { data in
                    showCamera = false
                    Task { await startAnalysis(imageData: data) }
                },
                onCancel: { showCamera = false }
            )
        }
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
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
            Text("Log a meal")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
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
                                colors: [PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.4), PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.0)],
                                center: .center, startRadius: 4, endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                        .symbolEffect(.pulse, options: .repeating)
                }

                Text("Snap a meal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                Text("PrecisionCalMacroAutopsy sees ingredients, prep,\nportions, and lipid sheen in 6 passes.")
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                PearlescentButton(action: {
                    if canScan {
                        showSourceDialog = true
                    } else {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showPaywall = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: canScan ? "camera" : "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(canScan ? "Snap or choose photo" : "Unlock unlimited scans")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                }
                .padding(.horizontal, 8)

                Button {
                    showManualEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Log manually")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracottaDeep)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorites")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                .padding(.horizontal, 4)
                .padding(.top, 8)

            ForEach(favorites) { favorite in
                GlassCard(cornerRadius: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.amber)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(PrecisionCalMacroAutopsyTheme.amber.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(favorite.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(Int(favorite.totalCalories)) cal • \(favorite.items.count) item\(favorite.items.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                        }
                        Spacer()
                        Button {
                            logFavorite(favorite)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(PrecisionCalMacroAutopsyTheme.terracotta, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(favorite)
                        try? modelContext.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } label: { Label("Remove favorite", systemImage: "star.slash") }
                }
            }
        }
    }

    /// One-tap logging: clones the saved composition into a new completed meal for right now.
    private func logFavorite(_ favorite: FavoriteMeal) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let meal = Meal(
            createdAt: Date(),
            title: favorite.name,
            status: "complete",
            totalCalories: favorite.totalCalories,
            totalProtein: favorite.totalProtein,
            totalCarbs: favorite.totalCarbs,
            totalFat: favorite.totalFat,
            totalFiber: favorite.totalFiber,
            totalSugar: favorite.totalSugar,
            waterContentMl: favorite.waterContentMl
        )
        modelContext.insert(meal)
        for snapshot in favorite.items {
            let item = MealItem(
                name: snapshot.name,
                preparation: snapshot.preparation,
                grams: snapshot.grams,
                calories: snapshot.calories,
                protein: snapshot.protein,
                carbs: snapshot.carbs,
                fat: snapshot.fat,
                fiber: snapshot.fiber,
                sugar: snapshot.sugar,
                waterMl: snapshot.waterMl
            )
            item.meal = meal
            meal.items.append(item)
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                        case .pass2LipidDiscovered:
                            currentPass = 3
                        case .pass3LipidVerified:
                            currentPass = 4
                        case .pass4Weighed:
                            currentPass = 5
                        case .pass5Mapped:
                            currentPass = 6
                        case .pass6Synthesized:
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
        meal.saturatedFat = result.saturatedFat
        meal.unsaturatedFat = result.unsaturatedFat
        meal.transFat = result.transFat
        meal.hiddenFatAddedCalories = result.hiddenFatAddedCalories
        meal.hiddenFatAddedFatG = result.hiddenFatAddedFatG
        meal.hiddenFatTargetItem = result.hiddenFatTargetItem
        meal.hiddenFatMechanism = result.hiddenFatMechanism
        meal.micronutrients = result.micronutrients
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
                waterMl: it.waterMl,
                weightSource: it.weightSource
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
