import SwiftUI
import SwiftData
import PhotosUI
import AuthenticationServices
import RevenueCat

/// Value-first entry funnel: the user experiences a full 6-pass analysis before
/// ever seeing the paywall. Orchestrates scan → analyze → paywall → sign-in →
/// reveal. The current stage is persisted via AppStorage and the captured meal
/// lives in SwiftData, so a force-close returns the user to the exact step.
struct FirstScanFunnelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreViewModel.self) private var store
    @AppStorage(OnboardingFunnelStage.storageKey) private var stageRaw: String = OnboardingFunnelStage.firstScan.rawValue
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]

    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var currentPass: Int = 1
    @State private var quickItems: [String] = []
    @State private var analysisError: String?
    @State private var didStartAnalysis = false
    @State private var showResultSheet = false

    private var stage: OnboardingFunnelStage {
        OnboardingFunnelStage(rawValue: stageRaw) ?? .firstScan
    }

    /// The first-scan meal — during the funnel it's always the most recent (and only) meal.
    private var funnelMeal: Meal? { meals.first }

    var body: some View {
        ZStack {
            switch stage {
            case .firstScan:
                scanPrompt
                    .transition(.opacity)
            case .analyzing:
                analyzingScreen
                    .transition(.opacity)
            case .paywall:
                PaywallView(store: store, isMandatory: true)
                    .onAppear { if store.hasAccess { setStage(.signin) } }
                    .onChange(of: store.hasAccess) { _, has in
                        if has { setStage(.signin) }
                    }
                    .transition(.opacity)
            case .signin:
                FunnelSignInScreen(onFinished: { setStage(.reveal) })
                    .transition(.opacity)
            case .reveal:
                revealScreen
                    .transition(.opacity)
            case .done, .questionnaire:
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.45), value: stage)
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAndStart(item: newItem) }
        }
    }

    private func setStage(_ newStage: OnboardingFunnelStage) {
        withAnimation(.easeInOut(duration: 0.45)) {
            stageRaw = newStage.rawValue
        }
    }

    // MARK: - Stage 1: Scan prompt

    private var scanPrompt: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PrecisionCalTheme.terracotta.opacity(0.45), PrecisionCalTheme.terracotta.opacity(0)],
                                center: .center, startRadius: 6, endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 12)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 92, weight: .thin))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .symbolEffect(.pulse, options: .repeating)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                }
                .frame(height: 240)

                VStack(spacing: 12) {
                    Text("CALIBRATION SCAN")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                    Text("Scan your first meal")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Scan your first meal to calibrate your protocol and run your initial 6-pass analysis.")
                        .font(.system(size: 16))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 28)
                }
            }

            Spacer()

            if let analysisError {
                Text(analysisError)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.fatColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }

            PearlescentButton(action: {
                analysisError = nil
                showPicker = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Scan my meal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)

            Text("Your protocol calibrates from this first scan.")
                .font(.system(size: 12))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Stage 2: Analyzing

    private var analyzingScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 24) {
                mealThumbnail

                Text("Running your 6-pass analysis")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                AnalysisProgressBar(currentPass: currentPass)
                    .padding(.horizontal, 20)

                if !quickItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(quickItems.prefix(5).enumerated()), id: \.offset) { idx, name in
                            IdentifiedItemRow(name: name, delay: Double(idx) * 0.08)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            if analysisError != nil {
                VStack(spacing: 12) {
                    Text(analysisError ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(PrecisionCalTheme.fatColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button {
                        retryFromScratch()
                    } label: {
                        Text("Try another photo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                    }
                }
                .padding(.bottom, 28)
            } else {
                Text("Cal is isolating items, hunting hidden fats,\nweighing portions and cross-referencing USDA.")
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.bottom, 28)
            }
        }
        .onAppear { resumeOrStartAnalysis() }
    }

    private var mealThumbnail: some View {
        Color(.secondarySystemBackground)
            .frame(width: 150, height: 150)
            .overlay {
                if let data = funnelMeal?.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
            }
            .clipShape(.rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
            }
            .shadow(color: PrecisionCalTheme.terracotta.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    // MARK: - Stage 5: Reveal

    private var revealScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PrecisionCalTheme.sage.opacity(0.5), PrecisionCalTheme.sage.opacity(0)],
                            center: .center, startRadius: 6, endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 14)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(PrecisionCalTheme.sage)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }

            VStack(spacing: 12) {
                Text("Protocol calibrated")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("Your trial is active and your account is secured. Here's your first Nutritional Autopsy.")
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 30)
            }

            Spacer()

            PearlescentButton(action: { showResultSheet = true }) {
                HStack(spacing: 10) {
                    Text("Reveal my results")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            // Auto-present so the reveal feels immediate after sign-in.
            if !showResultSheet { showResultSheet = true }
        }
        .sheet(isPresented: $showResultSheet, onDismiss: { setStage(.done) }) {
            if let meal = funnelMeal {
                MealAnalysisSheet(meal: meal, quickItems: quickItems, currentPass: 6)
                    .presentationDetents([.large])
                    .presentationBackground(.clear)
            }
        }
    }

    // MARK: - Analysis pipeline

    @MainActor
    private func loadAndStart(item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              UIImage(data: data) != nil else {
            analysisError = "Couldn't read that photo. Please try another."
            return
        }
        let meal = Meal(imageData: data, status: "analyzing")
        modelContext.insert(meal)
        try? modelContext.save()
        currentPass = 1
        quickItems = []
        analysisError = nil
        didStartAnalysis = false
        setStage(.analyzing)
    }

    /// Called when the analyzing screen appears — either start fresh or resume
    /// after a relaunch. If the meal already completed, jump straight to the paywall.
    private func resumeOrStartAnalysis() {
        guard let meal = funnelMeal else {
            // No meal to analyze (edge case) — return to the scan prompt.
            setStage(.firstScan)
            return
        }
        if meal.status == "complete" && !meal.items.isEmpty {
            setStage(.paywall)
            return
        }
        guard !didStartAnalysis else { return }
        didStartAnalysis = true
        analysisError = nil
        currentPass = max(1, currentPass)
        startAnalysis(for: meal)
    }

    @MainActor
    private func startAnalysis(for meal: Meal) {
        guard let imageData = meal.imageData else {
            analysisError = "The scan image is missing. Please scan again."
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                let result = try await AIService.shared.analyzeChain(imageData: imageData) { event in
                    Task { @MainActor in
                        switch event {
                        case .pass1Identified(let items, let title):
                            quickItems = items
                            if meal.title.isEmpty || meal.title == "Meal" { meal.title = title }
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Pass 6 complete — interrupt BEFORE the breakdown renders.
                    setStage(.paywall)
                }
            } catch {
                await MainActor.run {
                    meal.status = "failed"
                    meal.qcNotes = error.localizedDescription
                    try? modelContext.save()
                    analysisError = "Analysis hit a snag. Please try another photo."
                }
            }
        }
    }

    /// Discard the failed meal and return to the scan prompt for a fresh attempt.
    private func retryFromScratch() {
        if let meal = funnelMeal {
            modelContext.delete(meal)
            try? modelContext.save()
        }
        didStartAnalysis = false
        quickItems = []
        currentPass = 1
        analysisError = nil
        setStage(.firstScan)
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

/// Sign in with Apple step that "locks in" the user's anonymous account by
/// associating it with RevenueCat (so the subscription follows their Apple ID).
/// Uses Apple's standard `SignInWithAppleButton` for HIG compliance.
private struct FunnelSignInScreen: View {
    let onFinished: () -> Void

    @Environment(StoreViewModel.self) private var store
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PrecisionCalTheme.terracotta.opacity(0.4), PrecisionCalTheme.terracotta.opacity(0)],
                            center: .center, startRadius: 6, endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 14)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }

            VStack(spacing: 12) {
                Text("Secure your account")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("Lock in your protocol and trial so they follow you across devices. Private and one tap.")
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 8)

            Spacer()

            if let errorText {
                Text(errorText)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.fatColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 24)
            .disabled(isWorking)
            .opacity(isWorking ? 0.6 : 1)

            Button {
                onFinished()
            } label: {
                Text("Maybe later")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            .padding(.top, 14)
            .padding(.bottom, 28)
            .disabled(isWorking)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                onFinished()
                return
            }
            isWorking = true
            let userID = credential.user
            let email = credential.email?.lowercased()
            UserDefaults.standard.set(userID, forKey: "appleUserID")
            if let email { UserDefaults.standard.set(email, forKey: "appleUserEmail") }

            Task {
                // Lock the anonymous RevenueCat identity to this Apple ID so the
                // subscription/trial follows the user across devices.
                _ = try? await Purchases.shared.logIn(userID)
                // Honor the owner allow-list (auto-unlock for the app owner).
                if let email, OwnerAuthService.ownerEmails.contains(email) {
                    store.setOwnerOverride(true)
                }
                await MainActor.run {
                    isWorking = false
                    onFinished()
                }
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User dismissed the sheet — let them try again or skip.
                return
            }
            errorText = "Sign-in didn't complete. You can try again or continue."
        }
    }
}
