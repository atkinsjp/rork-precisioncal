import SwiftUI
import SwiftData

struct FrostedScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreViewModel.self) private var store
    @Query private var profiles: [UserProfile]

    @State private var scannedBarcode: String?
    @State private var isLookingUp = false
    @State private var product: ScannedProduct?
    @State private var showProduct = false
    @State private var error: String?
    @State private var milkRippleProgress: CGFloat = 0
    @State private var milkRippleVisible = false
    @State private var showLibrary = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            // Camera background (or simulator placeholder)
            CameraProxyView(realCamera: {
                BarcodeCameraView(onScanned: handleScanned)
            }, onManualBarcode: handleScanned)
            .ignoresSafeArea()
            .background(Color.black)

            // Dimmed overlay around viewfinder
            scannerMask

            // Top + bottom chrome
            VStack {
                topChrome
                Spacer()
                bottomChrome
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)

            // Center viewfinder + thinking orb
            viewfinder

            // Soft Milk full-screen ripple on success
            if milkRippleVisible {
                GeometryReader { geo in
                    let r = milkRippleProgress * max(geo.size.width, geo.size.height) * 1.6
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.55 * (1 - milkRippleProgress)),
                                    Color.white.opacity(0.0),
                                ],
                                center: .center, startRadius: 0, endRadius: max(r, 1)
                            )
                        )
                        .frame(width: r * 2, height: r * 2)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showProduct, onDismiss: {
            scannedBarcode = nil
            product = nil
        }) {
            if let p = product {
                ProductDetailSheet(product: p, profile: profiles.first)
                    .presentationDetents([.large])
                    .presentationBackground(.clear)
            }
        }
        .alert("Couldn't read product", isPresented: .constant(error != nil), actions: {
            Button("OK") {
                error = nil
                scannedBarcode = nil
            }
        }, message: { Text(error ?? "") })
        .sheet(isPresented: $showLibrary) {
            ScannedProductsLibraryView(isModal: true)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
    }

    // MARK: - Chrome

    private var topChrome: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCAN")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Frosted Scanner")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                let gen = UIImpactFeedbackGenerator(style: .soft)
                gen.impactOccurred()
                showLibrary = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Pantry")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            Text(isLookingUp ? "Crossreferencing your profile…" : "Center any barcode in the frame")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity)
            Text("EAN • UPC • QR • Code128")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 22)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Viewfinder mask

    private var scannerMask: some View {
        GeometryReader { geo in
            let w = min(geo.size.width - 60, 320)
            let h = w * 0.78
            let rect = CGRect(
                x: (geo.size.width - w) / 2,
                y: (geo.size.height - h) / 2,
                width: w,
                height: h
            )
            ZStack {
                Color.black.opacity(0.45)
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
            }
            .ignoresSafeArea()
        }
    }

    private var viewfinder: some View {
        GeometryReader { geo in
            let w = min(geo.size.width - 60, 320)
            let h = w * 0.78
            ZStack {
                // Frosted edge stroke
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 2)
                    .frame(width: w, height: h)

                // Corner accents
                CornerAccents()
                    .stroke(PrecisionCalTheme.terracotta, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: w, height: h)

                // Thinking state
                if isLookingUp {
                    BreathingOrb(size: 90, color: .white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .animation(.easeInOut(duration: 0.4), value: isLookingUp)
        }
    }

    // MARK: - Actions

    private func handleScanned(_ code: String) {
        guard !isLookingUp, scannedBarcode != code else { return }
        guard store.hasAccess else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            scannedBarcode = nil
            showPaywall = true
            return
        }
        scannedBarcode = code
        isLookingUp = true

        Task {
            do {
                let result = try await BarcodeService.shared.fetchProductData(
                    barcodeID: code,
                    context: modelContext
                )
                triggerSuccessFeedback()
                isLookingUp = false
                // brief delay so the milk ripple gets to play
                try? await Task.sleep(for: .milliseconds(220))
                product = result
                showProduct = true
            } catch {
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.error)
                isLookingUp = false
                self.error = error.localizedDescription
            }
        }
    }

    private func triggerSuccessFeedback() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        milkRippleProgress = 0
        milkRippleVisible = true
        withAnimation(.easeOut(duration: 0.85)) {
            milkRippleProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            milkRippleVisible = false
        }
    }
}

private struct CornerAccents: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len: CGFloat = 26
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        return p
    }
}
