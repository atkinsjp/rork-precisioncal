import SwiftUI
import SwiftData

struct ScannedProductsLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedProduct.lastScannedAt, order: .reverse) private var products: [ScannedProduct]
    @Query private var profiles: [UserProfile]

    @State private var search: String = ""
    @State private var selectedFilter: RiskFilter = .all
    @State private var detail: ScannedProduct?
    @State private var animate: Bool = false

    enum RiskFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        var id: String { rawValue }
    }

    private var filtered: [ScannedProduct] {
        var arr = products
        if selectedFilter != .all {
            arr = arr.filter { $0.riskLevel.lowercased() == selectedFilter.rawValue.lowercased() }
        }
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = search.lowercased()
            arr = arr.filter {
                $0.name.lowercased().contains(q) ||
                $0.brand.lowercased().contains(q) ||
                $0.barcode.contains(q) ||
                $0.ingredients.lowercased().contains(q)
            }
        }
        return arr
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        statsHeader

                        searchBar

                        filterChips

                        if filtered.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, p in
                                Button {
                                    detail = p
                                } label: {
                                    ProductLibraryRow(product: p)
                                }
                                .buttonStyle(.plain)
                                .opacity(animate ? 1 : 0)
                                .offset(y: animate ? 0 : 16)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(min(0.04 * Double(idx), 0.5)), value: animate)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        modelContext.delete(p)
                                        try? modelContext.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $detail) { p in
                ProductDetailSheet(product: p, profile: profiles.first)
                    .presentationDetents([.large])
                    .presentationBackground(.clear)
            }
            .onAppear {
                animate = false
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                    animate = true
                }
            }
        }
    }

    private var statsHeader: some View {
        GlassCard {
            HStack(spacing: 0) {
                statBlock(label: "Items", value: "\(products.count)", color: PrecisionCalTheme.terracotta)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                statBlock(label: "Low risk", value: "\(products.filter { $0.riskLevel == "low" }.count)", color: PrecisionCalTheme.sage)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                statBlock(label: "High risk", value: "\(products.filter { $0.riskLevel == "high" }.count)", color: PrecisionCalTheme.terracotta)
            }
            .padding(.vertical, 16)
        }
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            TextField("Search your pantry", text: $search)
                .font(.system(size: 14))
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
                )
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RiskFilter.allCases) { f in
                    let isOn = selectedFilter == f
                    Button {
                        let gen = UISelectionFeedbackGenerator()
                        gen.selectionChanged()
                        selectedFilter = f
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isOn ? .white : PrecisionCalTheme.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background {
                                Capsule()
                                    .fill(isOn ? PrecisionCalTheme.textPrimary : Color.white.opacity(0.5))
                                    .overlay(Capsule().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 4)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 36))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("No products yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("Scan barcodes to build your pantry. Items you scan often will be one tap away.")
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProductLibraryRow: View {
    let product: ScannedProduct

    var body: some View {
        GlassCard(cornerRadius: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(riskColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(riskColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name.isEmpty ? "Unknown product" : product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !product.brand.isEmpty {
                            Text(product.brand)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                        }
                        Text("•")
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                        Text("\(Int(product.calories)) kcal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                        if product.scanCount > 1 {
                            Text("•")
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(product.scanCount)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            .padding(14)
        }
    }

    private var riskColor: Color {
        switch product.riskLevel {
        case "high": PrecisionCalTheme.terracotta
        case "moderate": PrecisionCalTheme.fatColor
        default: PrecisionCalTheme.sage
        }
    }
}
