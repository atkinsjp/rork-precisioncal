import SwiftUI
import SwiftData

/// Comments view for a Sanctuary post — every comment runs through the StewardshipFilter.
struct SanctuaryCommentSheet: View {
    let post: SanctuaryPost

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var draft: String = ""
    @State private var submitting: Bool = false
    @FocusState private var focused: Bool

    private var profile: UserProfile? { profiles.first }

    private var visibleComments: [SanctuaryComment] {
        post.comments
            .filter { $0.state == .approved || $0.state == .reviewing }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            stewardBanner

                            if visibleComments.isEmpty {
                                emptyState
                            } else {
                                ForEach(visibleComments) { c in
                                    commentRow(c)
                                }
                            }

                            Color.clear.frame(height: 8)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                    }
                    .scrollIndicators(.hidden)

                    composer
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Pieces

    private var stewardBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(PrecisionCalTheme.sage)
                .font(.system(size: 11, weight: .bold))
            Text("Every reply is read by the Steward before it appears.")
                .font(.custom("Georgia-Italic", size: 12))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 24))
                .foregroundStyle(PrecisionCalTheme.sage)
            Text("Be the first to respond.")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func commentRow(_ c: SanctuaryComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(PrecisionCalTheme.terracotta.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text(c.authorInitial)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.terracottaDeep)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    if c.state == .reviewing {
                        Text("STEWARD READING")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(PrecisionCalTheme.glassStroke.opacity(0.4)))
                    }
                    Spacer()
                    Text(relative(c.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Text(c.bodyText)
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(2)
                    .opacity(c.state == .reviewing ? 0.65 : 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1))
        )
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a kind, honest reply…", text: $draft, axis: .vertical)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
                    )

                Button(action: submit) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                            .shadow(color: PrecisionCalTheme.terracotta.opacity(0.4), radius: 8, x: 0, y: 4)
                        if submitting {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var canSubmit: Bool {
        !submitting && draft.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }

    private func submit() {
        guard canSubmit else { return }
        let name = profile?.name.isEmpty == false ? profile!.name : "You"
        let initial = String(name.prefix(1)).uppercased()
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        let comment = SanctuaryComment(
            authorName: name,
            authorInitial: initial,
            bodyText: trimmed,
            state: .reviewing
        )
        comment.post = post
        modelContext.insert(comment)
        post.comments.append(comment)
        try? modelContext.save()

        draft = ""
        submitting = true

        Task {
            await StewardshipService.shared.submit(comment: comment, context: modelContext)
            await MainActor.run { submitting = false }
        }
    }
}
