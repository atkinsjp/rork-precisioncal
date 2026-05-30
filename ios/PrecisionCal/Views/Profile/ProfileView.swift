import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreViewModel.self) private var store
    @Environment(OwnerAuthService.self) private var ownerAuth
    @Query private var profiles: [UserProfile]
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @Query(sort: \Calibration.createdAt, order: .reverse) private var calibrations: [Calibration]
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    @State private var calibrating: Bool = false
    @State private var calibrationToast: String? = nil
    @State private var showPaywall: Bool = false

    private let supportURL = URL(string: "mailto:support@atkins-media.com")!
    @State private var showDisclaimer: Bool = false
    @State private var legalSheet: LegalDocumentView.Kind? = nil
    @State private var showSignOutConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var manageSubError: String? = nil

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

                    subscriptionCard

                    calibrationCard

                    disclaimerCard

                    legalCard

                    #if DEBUG
                    ownerModeCard
                    #endif

                    accountCard

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
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
            .sheet(isPresented: $showDisclaimer) {
                DisclaimerSheet()
            }
            .sheet(item: $legalSheet) { kind in
                LegalDocumentView(kind: kind)
            }
            .alert("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { signOut() }
            } message: {
                Text("You'll be signed out of Apple ID on this device. Your local data stays until you delete your account.")
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) { deleteAccount() }
            } message: {
                Text("This permanently erases your profile, meals, scans, calibrations, sanctuary posts, and all local data on this device. This cannot be undone. Active subscriptions are managed by Apple and must be cancelled separately.")
            }
            .alert("Couldn't open Subscriptions", isPresented: Binding(get: { manageSubError != nil }, set: { if !$0 { manageSubError = nil } })) {
                Button("OK", role: .cancel) { manageSubError = nil }
            } message: {
                Text(manageSubError ?? "")
            }
        }
    }

    private var accountCard: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    Task { await openManageSubscriptions() }
                } label: {
                    accountRowLabel(
                        icon: "creditcard.fill",
                        label: "Manage Subscription",
                        sublabel: store.isPremium ? "Change plan or cancel" : "View available plans",
                        tint: PrecisionCalTheme.terracotta,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56).opacity(0.5)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showSignOutConfirm = true
                } label: {
                    accountRowLabel(
                        icon: "rectangle.portrait.and.arrow.right",
                        label: "Sign Out",
                        sublabel: ownerAuth.savedAppleUserEmail ?? "Clear Apple ID session",
                        tint: PrecisionCalTheme.textPrimary,
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56).opacity(0.5)

                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    showDeleteConfirm = true
                } label: {
                    accountRowLabel(
                        icon: "trash.fill",
                        label: isDeletingAccount ? "Deleting…" : "Delete Account",
                        sublabel: "Permanently erase all data on this device",
                        tint: .red,
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
            .padding(.vertical, 4)
        }
    }

    private func accountRowLabel(icon: String, label: String, sublabel: String, tint: Color, trailing: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint == .red ? Color.red : PrecisionCalTheme.textPrimary)
                Text(sublabel)
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @MainActor
    private func openManageSubscriptions() async {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
                return
            } catch {
                // Fall through to URL fallback
            }
        }
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            await UIApplication.shared.open(url)
        } else {
            manageSubError = "Open Settings → Apple ID → Subscriptions to manage your plan."
        }
    }

    private func signOut() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ownerAuth.signOut()
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        // Wipe every SwiftData model we manage.
        let modelTypes: [any PersistentModel.Type] = [
            Meal.self,
            MealItem.self,
            WaterEntry.self,
            UserProfile.self,
            ScannedProduct.self,
            Calibration.self,
            SanctuaryPost.self,
            SanctuaryComment.self,
            RoadmapInsight.self,
            BodyWeightEntry.self,
            ShoppingItem.self,
        ]
        for type in modelTypes {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()

        // Clear Apple ID + owner override.
        ownerAuth.signOut()

        // Wipe every persisted preference for the app's bundle.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()

        // Bounce user back to onboarding.
        hasOnboarded = false
        isDeletingAccount = false
    }

    private var disclaimerCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showDisclaimer = true
        } label: {
            GlassCard(cornerRadius: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(PrecisionCalTheme.terracotta.opacity(0.14))
                            .frame(width: 32, height: 32)
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disclaimer & Sources")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        Text("Medical disclaimer plus citations for all nutrition guidance.")
                            .font(.system(size: 12))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                .padding(18)
            }
        }
        .buttonStyle(.plain)
    }

    private var subscriptionCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if !store.isPremium { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: store.isPremium ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isPremium ? "PrecisionCal Pro" : (store.isInTrial ? "Free Trial" : "Upgrade to Pro"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Text(store.isPremium
                         ? "Active — thank you for supporting calibration."
                         : (store.isInTrial
                            ? "\(store.trialDaysRemaining) day\(store.trialDaysRemaining == 1 ? "" : "s") left · subscribe to keep access."
                            : "Subscribe to unlock the app."))
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if !store.isPremium {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta.opacity(0.5), PrecisionCalTheme.glassStroke],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.12), radius: 14, x: 0, y: 8)
            }
        }
        .buttonStyle(.plain)
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
                        Text("\(p.ageYears) yrs • \(Int(p.weightKg * 2.20462)) lb")
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

                TargetRow(icon: "flame.fill", color: PrecisionCalTheme.proteinColor, label: "Calories", value: "\(p.dailyCalorieTarget) cal")
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
                            .tint(PrecisionCalTheme.textPrimary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: store.hasAccess ? "arrow.triangle.2.circlepath" : "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(calibrating ? "Recalibrating…" : "Re-run calibration")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.1)
                    if !store.hasAccess && !calibrating {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(PrecisionCalTheme.terracotta))
                    }
                }
                .foregroundStyle(PrecisionCalTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    Capsule().fill(
                        LinearGradient(
                            colors: [PrecisionCalTheme.terracotta.opacity(0.28), PrecisionCalTheme.terracottaDeep.opacity(0.32)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule().stroke(PrecisionCalTheme.terracotta.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.18), radius: 8, x: 0, y: 4)
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

    private var legalCard: some View {
        GlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    legalSheet = .privacy
                } label: {
                    legalRowLabel(icon: "hand.raised.fill", label: "Privacy Policy", trailing: "chevron.right")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56).opacity(0.5)
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    legalSheet = .terms
                } label: {
                    legalRowLabel(icon: "doc.text.fill", label: "Terms of Service", trailing: "chevron.right")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56).opacity(0.5)
                Link(destination: supportURL) {
                    legalRowLabel(icon: "envelope.fill", label: "Contact Support", trailing: "arrow.up.right")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                })
            }
            .padding(.vertical, 4)
        }
    }

    private func legalRowLabel(icon: String, label: String, trailing: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PrecisionCalTheme.terracotta.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var ownerModeCard: some View {
        let bindingOn = Binding<Bool>(
            get: { store.ownerOverride },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                store.setOwnerOverride(newValue)
            }
        )
        return GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PrecisionCalTheme.terracotta.opacity(0.14))
                            .frame(width: 32, height: 32)
                        Image(systemName: "key.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Owner / Tester Mode")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        Text(store.ownerOverride ? "All Pro features unlocked." : "Unlock all Pro features without a subscription.")
                            .font(.system(size: 12))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Toggle("", isOn: bindingOn)
                        .labelsHidden()
                        .tint(PrecisionCalTheme.terracotta)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    Task { await ownerAuth.verifyOwner() }
                } label: {
                    HStack(spacing: 8) {
                        if ownerAuth.isVerifying {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(ownerAuth.isVerifying ? "Verifying…" : (store.ownerOverride && ownerAuth.savedAppleUserID != nil ? "Apple ID verified" : "Auto-unlock with Apple ID"))
                            .font(.system(size: 13, weight: .bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        Capsule().fill(Color.black.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .disabled(ownerAuth.isVerifying)

                if let err = ownerAuth.lastError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.85))
                }

                Text("Sign in with Apple to auto-unlock for approved owner Apple IDs. Manual toggle is for internal testers only.")
                    .font(.system(size: 11))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            .padding(18)
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
        guard store.hasAccess else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showPaywall = true
            return
        }
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
