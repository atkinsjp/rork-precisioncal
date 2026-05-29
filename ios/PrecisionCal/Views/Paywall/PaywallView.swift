import SwiftUI
import RevenueCat

struct PaywallView: View {
    var store: StoreViewModel
    /// When true, the paywall cannot be dismissed (no close button) — the user
    /// must subscribe (or restore) to continue using the app.
    var isMandatory: Bool = false
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedPackageID: String?
    @State private var legalSheet: LegalDocumentView.Kind? = nil

    private var packages: [Package] {
        guard let current = store.offerings?.current else { return [] }
        // Order: yearly, monthly, weekly when available
        let order: [PackageType] = [.annual, .monthly, .weekly, .twoMonth, .threeMonth, .sixMonth, .lifetime]
        let known = order.compactMap { type in current.availablePackages.first(where: { $0.packageType == type }) }
        let extras = current.availablePackages.filter { !known.contains($0) }
        return known + extras
    }

    private var selectedPackage: Package? {
        packages.first(where: { $0.identifier == selectedPackageID }) ?? packages.first
    }

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    var body: some View {
        ZStack {
            MeshBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                    benefits
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)

                    if store.isLoading && packages.isEmpty {
                        VStack(spacing: 14) {
                            BreathingOrb(size: 56)
                            Text("Loading plans…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if packages.isEmpty {
                        ContentUnavailableView(
                            "Plans unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Please try again in a moment.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(packages, id: \.identifier) { pkg in
                                packageRow(pkg)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)
                    }

                    purchaseButton
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)

                    footer
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                }
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            if !isMandatory {
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
        }
        .sheet(item: $legalSheet) { kind in
            LegalDocumentView(kind: kind)
        }
        .alert("Something went wrong", isPresented: .init(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { close() }
        }
        .onAppear {
            if selectedPackageID == nil {
                // Prefer yearly default
                selectedPackageID = packages.first(where: { $0.packageType == .annual })?.identifier
                    ?? packages.first?.identifier
            }
        }
        .onChange(of: packages.map(\.identifier)) { _, ids in
            if selectedPackageID == nil || !(ids.contains(selectedPackageID ?? "")) {
                selectedPackageID = ids.first(where: { id in
                    packages.first(where: { $0.identifier == id })?.packageType == .annual
                }) ?? ids.first
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PrecisionCalTheme.terracotta.opacity(0.45), PrecisionCalTheme.terracotta.opacity(0)],
                            center: .center, startRadius: 4, endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 18)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.4), radius: 20, x: 0, y: 12)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("PRECISIONCAL PRO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)

                Text("Unlock your full\ncalibration")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(2)

                Text("AI-personalized nutrition, weekly recalibration & deep insights.")
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 10) {
            BenefitRow(
                icon: "wand.and.stars",
                title: "Unlimited AI scans",
                subtitle: "Identify any meal or product in a snap."
            )
            BenefitRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Sunday Calibration",
                subtitle: "Weekly protocol pivots tuned to your data."
            )
            BenefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Deep trend insights",
                subtitle: "See what's actually moving your goals."
            )
            BenefitRow(
                icon: "leaf.fill",
                title: "Personalized protocol",
                subtitle: "Adapts to your goals, allergies & meds."
            )
        }
    }

    // MARK: - Package row

    private func packageRow(_ package: Package) -> some View {
        let isSelected = (selectedPackageID ?? packages.first?.identifier) == package.identifier
        let title = displayTitle(for: package)
        let priceText = package.storeProduct.localizedPriceString
        let perUnit = perUnitString(for: package)
        let savings = savingsString(for: package)

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            selectedPackageID = package.identifier
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? PrecisionCalTheme.terracotta : PrecisionCalTheme.glassStroke, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(PrecisionCalTheme.terracotta)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        if let savings {
                            Text(savings)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(PrecisionCalTheme.sage))
                        }
                    }
                    if let perUnit {
                        Text(perUnit)
                            .font(.system(size: 12))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }

                Spacer()

                Text(priceText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? PrecisionCalTheme.terracotta.opacity(0.10) : Color.white.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? PrecisionCalTheme.terracotta : PrecisionCalTheme.glassStroke,
                                lineWidth: isSelected ? 1.6 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Purchase button

    private var purchaseButton: some View {
        PearlescentButton {
            guard let pkg = selectedPackage else { return }
            Task { await store.purchase(package: pkg) }
        } label: {
            HStack(spacing: 10) {
                if store.isPurchasing {
                    ProgressView().tint(.white).scaleEffect(0.9)
                }
                Text(store.isPurchasing ? "Processing…" : ctaLabel)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
            }
        }
        .disabled(store.isPurchasing || selectedPackage == nil)
        .opacity(selectedPackage == nil ? 0.5 : 1)
    }

    private var ctaLabel: String {
        if let pkg = selectedPackage,
           let intro = pkg.storeProduct.introductoryDiscount,
           intro.price == 0 {
            let value = intro.subscriptionPeriod.value
            let unit = unitString(intro.subscriptionPeriod.unit, value: value)
            return "Start \(value)-\(unit) free trial"
        }
        return "Continue"
    }

    // MARK: - Footer

    private var subscriptionDisclosure: String {
        guard let pkg = selectedPackage else {
            return "Subscription auto-renews until cancelled. Cancel anytime at least 24 hours before the end of the current period in your Apple ID Settings → Subscriptions. Payment will be charged to your Apple ID at confirmation of purchase."
        }
        let title = displayTitle(for: pkg)
        let price = pkg.storeProduct.localizedPriceString
        let periodLabel: String = {
            switch pkg.packageType {
            case .annual: return "year"
            case .sixMonth: return "6 months"
            case .threeMonth: return "3 months"
            case .twoMonth: return "2 months"
            case .monthly: return "month"
            case .weekly: return "week"
            case .lifetime: return ""
            default: return ""
            }
        }()
        let trial: String = {
            guard let intro = pkg.storeProduct.introductoryDiscount, intro.price == 0 else { return "" }
            let v = intro.subscriptionPeriod.value
            let u = unitString(intro.subscriptionPeriod.unit, value: v)
            return "After your \(v)-\(u) free trial, "
        }()
        if pkg.packageType == .lifetime {
            return "\(title) is a one-time purchase of \(price). Payment will be charged to your Apple ID at confirmation of purchase."
        }
        return "\(trial)\(title) PrecisionCal Pro is \(price) per \(periodLabel) and auto-renews until cancelled. Cancel anytime at least 24 hours before the end of the current period in your Apple ID Settings → Subscriptions. Payment will be charged to your Apple ID at confirmation of purchase."
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            .disabled(store.isPurchasing)

            Text(subscriptionDisclosure)
                .font(.system(size: 11))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .lineSpacing(2)

            HStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    legalSheet = .privacy
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
                .buttonStyle(.plain)

                Text("•")
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    legalSheet = .terms
                } label: {
                    Text("Terms of Use (EULA)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Formatting helpers

    private func displayTitle(for package: Package) -> String {
        switch package.packageType {
        case .annual: return "Yearly"
        case .sixMonth: return "6 months"
        case .threeMonth: return "3 months"
        case .twoMonth: return "2 months"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        default: return package.storeProduct.localizedTitle
        }
    }

    private func perUnitString(for package: Package) -> String? {
        let price = package.storeProduct.price as Decimal
        switch package.packageType {
        case .annual:
            let monthly = (price as NSDecimalNumber).doubleValue / 12.0
            return String(format: "%@%.2f / month", currencySymbol(package), monthly)
        case .sixMonth:
            let monthly = (price as NSDecimalNumber).doubleValue / 6.0
            return String(format: "%@%.2f / month", currencySymbol(package), monthly)
        case .threeMonth:
            let monthly = (price as NSDecimalNumber).doubleValue / 3.0
            return String(format: "%@%.2f / month", currencySymbol(package), monthly)
        case .monthly:
            return "Billed monthly"
        case .weekly:
            return "Billed weekly"
        case .lifetime:
            return "One-time purchase"
        default:
            return nil
        }
    }

    private func currencySymbol(_ package: Package) -> String {
        package.storeProduct.priceFormatter?.currencySymbol ?? ""
    }

    private func savingsString(for package: Package) -> String? {
        guard package.packageType == .annual,
              let monthly = packages.first(where: { $0.packageType == .monthly }) else { return nil }
        let yearlyPrice = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let monthlyPrice = (monthly.storeProduct.price as NSDecimalNumber).doubleValue
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let normalized = monthlyPrice * 12.0
        guard normalized > yearlyPrice else { return nil }
        let pct = Int(((normalized - yearlyPrice) / normalized * 100).rounded())
        guard pct > 0 else { return nil }
        return "SAVE \(pct)%"
    }

    private func unitString(_ unit: SubscriptionPeriod.Unit, value: Int) -> String {
        switch unit {
        case .day: return value == 1 ? "day" : "day"
        case .week: return value == 1 ? "week" : "week"
        case .month: return value == 1 ? "month" : "month"
        case .year: return value == 1 ? "year" : "year"
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PrecisionCalTheme.terracotta.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            Spacer()
        }
    }
}
