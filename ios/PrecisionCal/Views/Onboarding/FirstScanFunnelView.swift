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

    // Celebratory reveal animation
    @State private var scoreProgress: Double = 0
    @State private var displayedScore: Int = 0
    @State private var celebrate = false
    @State private var scoreCountTask: Task<Void, Never>?

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
                PaywallView(store: store, isMandatory: true, context: .postAnalysis)
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
        let score = funnelMeal?.mealScore ?? 0
        return VStack(spacing: 24) {
            Spacer()

            FunnelScoreRing(
                score: score,
                progress: scoreProgress,
                displayedScore: displayedScore,
                celebrate: celebrate
            )

            VStack(spacing: 12) {
                Text(scoreHeadline(for: score))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .multilineTextAlignment(.center)
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
        .onAppear { runScoreCelebration(score: score) }
        .onDisappear { scoreCountTask?.cancel() }
        .sheet(isPresented: $showResultSheet, onDismiss: { setStage(.done) }) {
            if let meal = funnelMeal {
                MealAnalysisSheet(meal: meal, quickItems: quickItems, currentPass: 6)
                    .presentationDetents([.large])
                    .presentationBackground(.clear)
            }
        }
    }

    private func scoreHeadline(for score: Int) -> String {
        switch score {
        case 80...: return "Outstanding meal"
        case 60..<80: return "Solid meal"
        default: return "Protocol calibrated"
        }
    }

    /// Drives the count-up number, ring fill, confetti burst and success haptic.
    private func runScoreCelebration(score: Int) {
        guard scoreCountTask == nil else { return }
        scoreProgress = 0
        displayedScore = 0
        celebrate = false

        withAnimation(.easeOut(duration: 1.1)) {
            scoreProgress = Double(max(0, min(100, score))) / 100.0
        }

        scoreCountTask = Task { @MainActor in
            // Brief beat so the ring starts sweeping before the burst lands.
            try? await Task.sleep(for: .milliseconds(120))
            let steps = max(1, score)
            let perStep = UInt64(1_000_000_000 / UInt64(max(1, min(60, steps))))
            for value in 0...score {
                if Task.isCancelled { return }
                displayedScore = value
                try? await Task.sleep(nanoseconds: perStep)
            }
            displayedScore = score
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                celebrate = true
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

/// Celebratory meal-score ring shown on the reveal screen: an animated sweep,
/// a count-up number, a soft success glow and a radiating confetti burst.
private struct FunnelScoreRing: View {
    let score: Int
    let progress: Double
    let displayedScore: Int
    let celebrate: Bool

    private var tint: Color {
        switch score {
        case 80...: return PrecisionCalTheme.sage
        case 60..<80: return PrecisionCalTheme.fatColor
        default: return PrecisionCalTheme.terracotta
        }
    }

    var body: some View {
        ZStack {
            // Ambient glow that blooms on completion.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(celebrate ? 0.5 : 0.28), tint.opacity(0)],
                        center: .center, startRadius: 6, endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .blur(radius: 16)
                .scaleEffect(celebrate ? 1.06 : 0.9)

            ConfettiBurst(tint: tint, isActive: celebrate)
                .frame(width: 260, height: 260)

            // Track
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 12)
                .frame(width: 176, height: 176)

            // Progress sweep
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.4), radius: 8, x: 0, y: 0)

            VStack(spacing: 2) {
                Text("\(displayedScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .contentTransition(.numericText(value: Double(displayedScore)))
                Text("MEAL SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(tint)
            }
            .scaleEffect(celebrate ? 1.0 : 0.94)
        }
        .frame(height: 260)
    }
}

/// Celebratory confetti: shards launch upward/outward on activation, then arc back down
/// under gravity while spinning and fading. Driven frame-by-frame by `TimelineView` so the
/// real per-frame opacity/position is rendered each tick — `withAnimation` can only interpolate
/// between start/end states, which collapses a launch→peak→fade arc into nothing.
private struct ConfettiBurst: View {
    let tint: Color
    let isActive: Bool

    @State private var startDate: Date?

    private let count = 20
    private let duration: CGFloat = 1.5
    private let palette: [Color] = [
        PrecisionCalTheme.sage,
        PrecisionCalTheme.terracotta,
        PrecisionCalTheme.fatColor,
        PrecisionCalTheme.sageLight
    ]

    /// Deterministic pseudo-random in 0...1 for a stable per-shard trajectory.
    private func rand(_ i: Int, _ salt: Int) -> CGFloat {
        let x = sin(Double(i &* 928_371 &+ salt &* 12_713)) * 43_758.5453
        return CGFloat(x - floor(x))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = progress(at: timeline.date)
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    shard(i, t: t)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear { if isActive { fire() } }
        .onChange(of: isActive) { _, active in if active { fire() } }
    }

    private func fire() {
        startDate = Date()
    }

    /// Eased 0...1 progress based on elapsed time since the burst fired.
    private func progress(at date: Date) -> CGFloat {
        guard let startDate else { return 0 }
        let elapsed = CGFloat(date.timeIntervalSince(startDate))
        let linear = max(0, min(1, elapsed / duration))
        // easeOut: fast launch, gentle settle.
        return 1 - pow(1 - linear, 2)
    }

    private func shard(_ i: Int, t: CGFloat) -> some View {
        let dir = rand(i, 1) * 2 - 1                 // horizontal direction -1...1
        let xSpeed = dir * (50 + rand(i, 2) * 130)   // lateral spread
        let upSpeed = 120 + rand(i, 3) * 130         // initial upward velocity
        let spin = (rand(i, 4) * 2 - 1) * 760        // total rotation in degrees
        let size = 6 + rand(i, 5) * 5

        let x = xSpeed * t
        let y = -upSpeed * t + 430 * t * t           // up, then gravity pulls down
        let opacity: CGFloat = {
            if t <= 0 { return 0 }
            if t < 0.12 { return t / 0.12 }
            if t > 0.72 { return max(0, 1 - (t - 0.72) / 0.28) }
            return 1
        }()

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(palette[i % palette.count])
            .frame(width: size, height: size * 1.8)
            .rotationEffect(.degrees(Double(spin * t)))
            .opacity(Double(opacity))
            .offset(x: x, y: y)
    }
}
