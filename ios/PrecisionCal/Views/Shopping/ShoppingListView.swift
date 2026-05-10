import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.addedAt, order: .reverse) private var items: [ShoppingItem]

    var isModal: Bool = true

    @State private var showAddFromPantry: Bool = false
    @State private var showAddCustom: Bool = false
    @State private var customName: String = ""
    @State private var confirmComplete: Bool = false
    @State private var animate: Bool = false

    private var keepCount: Int { items.filter { $0.keepOnList }.count }
    private var buyCount: Int { items.count - keepCount }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        statsHeader

                        addButtons

                        if items.isEmpty {
                            emptyState
                        } else {
                            instructionRow
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                ShoppingRow(item: item) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        item.keepOnList.toggle()
                                    }
                                    let gen = UIImpactFeedbackGenerator(style: .soft)
                                    gen.impactOccurred()
                                    try? modelContext.save()
                                }
                                .opacity(animate ? 1 : 0)
                                .offset(y: animate ? 0 : 14)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(min(0.04 * Double(idx), 0.4)), value: animate)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        modelContext.delete(item)
                                        try? modelContext.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)

                if !items.isEmpty {
                    VStack {
                        Spacer()
                        completeButton
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showAddFromPantry) {
                AddFromPantrySheet()
            }
            .alert("Add custom item", isPresented: $showAddCustom) {
                TextField("e.g. Bananas", text: $customName)
                Button("Cancel", role: .cancel) { customName = "" }
                Button("Add") { addCustom() }
            }
            .alert("Shopping complete?", isPresented: $confirmComplete) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, clear purchased") { completeShopping() }
            } message: {
                Text("\(buyCount) item\(buyCount == 1 ? "" : "s") will be removed (assumed purchased). \(keepCount) flagged item\(keepCount == 1 ? "" : "s") will stay on the list.")
            }
            .onAppear {
                animate = false
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.08)) {
                    animate = true
                }
            }
        }
    }

    private var statsHeader: some View {
        GlassCard {
            HStack(spacing: 0) {
                statBlock(label: "On list", value: "\(items.count)", color: PrecisionCalTheme.terracotta)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                statBlock(label: "To buy", value: "\(buyCount)", color: PrecisionCalTheme.sage)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                statBlock(label: "Keep", value: "\(keepCount)", color: PrecisionCalTheme.fatColor)
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

    private var addButtons: some View {
        HStack(spacing: 10) {
            Button {
                let gen = UIImpactFeedbackGenerator(style: .soft)
                gen.impactOccurred()
                showAddFromPantry = true
            } label: {
                addChip(icon: "shippingbox.fill", title: "From Pantry")
            }
            .buttonStyle(.plain)

            Button {
                let gen = UIImpactFeedbackGenerator(style: .soft)
                gen.impactOccurred()
                customName = ""
                showAddCustom = true
            } label: {
                addChip(icon: "plus.circle.fill", title: "Custom")
            }
            .buttonStyle(.plain)
        }
    }

    private func addChip(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(PrecisionCalTheme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PrecisionCalTheme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
                )
        }
    }

    private var instructionRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            Text("Tap items you couldn't purchase to keep them on next trip.")
                .font(.system(size: 12))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("Your list is empty")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("Add items from your pantry — your routine staples are one tap away.")
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }

    private var completeButton: some View {
        Button {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            confirmComplete = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                Text("Shopping Complete")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.35), radius: 14, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func addCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ShoppingItem(name: trimmed)
        modelContext.insert(item)
        try? modelContext.save()
        customName = ""
    }

    private func completeShopping() {
        for item in items {
            if item.keepOnList {
                // Keep, but reset flag for next trip.
                item.keepOnList = false
            } else {
                modelContext.delete(item)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Row

private struct ShoppingRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            GlassCard(cornerRadius: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(item.keepOnList ? PrecisionCalTheme.fatColor.opacity(0.22) : PrecisionCalTheme.sage.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: item.keepOnList ? "exclamationmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(item.keepOnList ? PrecisionCalTheme.fatColor : PrecisionCalTheme.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name.isEmpty ? "Unnamed item" : item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if !item.brand.isEmpty {
                                Text(item.brand)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                                Text("•").foregroundStyle(PrecisionCalTheme.textTertiary)
                            }
                            if item.keepOnList {
                                Text("Keep on next trip")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PrecisionCalTheme.fatColor)
                            } else if item.barcode.isEmpty {
                                Text("Custom")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                            } else {
                                Text("From pantry")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                    }
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add From Pantry sheet

private struct AddFromPantrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedProduct.scanCount, order: .reverse) private var products: [ScannedProduct]
    @Query private var existing: [ShoppingItem]

    @State private var search: String = ""
    @State private var selected: Set<String> = []

    private var filtered: [ScannedProduct] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return products }
        return products.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        searchBar

                        if products.isEmpty {
                            GlassCard {
                                VStack(spacing: 10) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 32))
                                        .foregroundStyle(PrecisionCalTheme.terracotta)
                                    Text("No pantry items yet")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                                    Text("Scan a barcode to start building your pantry.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            ForEach(filtered, id: \.barcode) { p in
                                let alreadyOnList = existing.contains(where: { $0.barcode == p.barcode })
                                let isSelected = selected.contains(p.barcode)
                                Button {
                                    if alreadyOnList { return }
                                    let gen = UISelectionFeedbackGenerator()
                                    gen.selectionChanged()
                                    if isSelected { selected.remove(p.barcode) }
                                    else { selected.insert(p.barcode) }
                                } label: {
                                    pantryRow(p, isSelected: isSelected, alreadyOnList: alreadyOnList)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)

                if !selected.isEmpty {
                    VStack {
                        Spacer()
                        Button {
                            addSelected()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Add \(selected.count) to list")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.35), radius: 14, x: 0, y: 6)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("Add from Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            TextField("Search pantry", text: $search)
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

    private func pantryRow(_ p: ScannedProduct, isSelected: Bool, alreadyOnList: Bool) -> some View {
        GlassCard(cornerRadius: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isSelected || alreadyOnList) ? PrecisionCalTheme.terracotta.opacity(0.18) : PrecisionCalTheme.sage.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: alreadyOnList ? "checkmark" : (isSelected ? "checkmark" : "shippingbox.fill"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle((isSelected || alreadyOnList) ? PrecisionCalTheme.terracotta : PrecisionCalTheme.sage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name.isEmpty ? "Unknown product" : p.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !p.brand.isEmpty {
                            Text(p.brand)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                        }
                        if p.scanCount > 1 {
                            Text("•").foregroundStyle(PrecisionCalTheme.textTertiary)
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(p.scanCount)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        }
                    }
                }
                Spacer()
                if alreadyOnList {
                    Text("On list")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.5)))
                }
            }
            .padding(14)
        }
        .opacity(alreadyOnList ? 0.55 : 1)
    }

    private func addSelected() {
        for p in products where selected.contains(p.barcode) {
            // Skip duplicates safely.
            if existing.contains(where: { $0.barcode == p.barcode }) { continue }
            let item = ShoppingItem(name: p.name, brand: p.brand, barcode: p.barcode)
            modelContext.insert(item)
        }
        try? modelContext.save()
    }
}
