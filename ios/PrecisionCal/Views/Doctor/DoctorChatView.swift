import SwiftUI
import SwiftData

/// Conversational chat with Dr. PrecisionCal — a PhD-level nutritionist
/// whose answers are personalized using the user's onboarding profile
/// (goals, conditions, allergies, medications, activity).
struct DoctorChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var messages: [DoctorMessage] = []
    @State private var draft: String = ""
    @State private var sending: Bool = false
    @State private var errorToast: String? = nil
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private let suggestions: [String] = [
        "What foods help with my goals?",
        "Any nutrients I should prioritize today?",
        "Are there foods I should limit given my conditions?",
        "How should I time meals around my activity?",
        "Best snacks that fit my profile?"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                VStack(spacing: 0) {
                    headerCard

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                if messages.isEmpty {
                                    introBubble
                                    suggestionGrid
                                } else {
                                    ForEach(messages) { msg in
                                        ChatBubble(message: msg)
                                            .id(msg.id)
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                                removal: .opacity
                                            ))
                                    }
                                    if sending {
                                        TypingBubble()
                                            .id("typing")
                                            .transition(.opacity)
                                    }
                                }
                                Color.clear.frame(height: 8).id("bottom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: messages.count) { _, _ in
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: sending) { _, _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }

                    inputBar
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
            }
            .overlay(alignment: .top) {
                if let toast = errorToast {
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(PrecisionCalTheme.terracottaDeep.opacity(0.95)))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.35), radius: 10, x: 0, y: 6)
                Image(systemName: "stethoscope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Dr. PrecisionCal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(PrecisionCalTheme.sage)
                        .frame(width: 6, height: 6)
                    Text("PhD Nutritionist • Online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(PrecisionCalTheme.glassStroke.opacity(0.5))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Intro & suggestions

    private var introBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                doctorAvatar(size: 30)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome\(profile?.name.isEmpty == false ? ", \(profile!.name)" : "").")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Text("I'm Dr. PrecisionCal. I've reviewed your profile — your goals, conditions, allergies, and medications. Ask me anything about food, nutrients, or how meals affect your health.")
                        .font(.system(size: 14))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineSpacing(3)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1)
                    )
            }
        }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.terracotta)
                .padding(.top, 6)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        send(text: s)
                    } label: {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PrecisionCalTheme.terracotta)
                            Text(s)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule().stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PrecisionCalTheme.glassStroke.opacity(0.4))
                .frame(height: 0.5)

            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask Dr. PrecisionCal…", text: $draft, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                                send(text: draft)
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(PrecisionCalTheme.glassStroke.opacity(0.7), lineWidth: 1)
                        )
                }

                Button {
                    let text = draft.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    send(text: text)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: canSend
                                        ? [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep]
                                        : [PrecisionCalTheme.glassStroke, PrecisionCalTheme.glassStroke],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: PrecisionCalTheme.terracotta.opacity(canSend ? 0.35 : 0), radius: 10, x: 0, y: 6)
                        if sending {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.2), value: canSend)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                Text("Educational information with cited sources — not medical advice. Always consult a licensed healthcare professional.")
                    .font(.system(size: 10))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var canSend: Bool {
        !sending && !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Send flow

    private func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !sending else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        let userMsg = DoctorMessage(role: .user, content: trimmed)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            messages.append(userMsg)
        }
        draft = ""
        sending = true

        let history = messages.dropLast().map { DoctorChatTurn(role: $0.role.rawValue, content: $0.content) }
        let summary = profileSummary()

        Task {
            do {
                let reply = try await AIService.shared.chatWithDoctor(
                    profileSummary: summary,
                    history: history,
                    userMessage: trimmed
                )
                await MainActor.run {
                    sending = false
                    let cleaned = reply.isEmpty
                        ? "I'm here — could you rephrase that for me?"
                        : reply
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        messages.append(DoctorMessage(role: .assistant, content: cleaned))
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    sending = false
                    showError("Couldn't reach Dr. PrecisionCal. Please try again.")
                }
            }
        }
    }

    private func profileSummary() -> String {
        guard let p = profile else { return "Anonymous user — no profile on file." }
        return """
        Name: \(p.name.isEmpty ? "Friend" : p.name)
        Age: \(p.ageYears)  Weight: \(Int(p.weightKg)) kg  Height: \(Int(p.heightCm)) cm
        Primary goal: \(p.goal)
        Goal tags: \(p.goalsTags.joined(separator: ", "))
        Medical history: \(p.medicalHistory.joined(separator: ", "))
        Specific conditions: \(p.specificConditions.joined(separator: ", "))
        Allergies: \(p.allergies.joined(separator: ", "))
        Medications: \(p.medications.joined(separator: ", "))
        Activity level: \(p.activityLevel)
        Daily targets: \(p.dailyCalorieTarget) kcal, \(p.dailyProteinTarget)g protein, \(p.dailyCarbTarget)g carbs, \(p.dailyFatTarget)g fat, \(p.dailyWaterTargetMl) ml water.
        Health protocol summary: \(p.healthProtocol.prefix(600))
        """
    }

    private func showError(_ msg: String) {
        withAnimation(.easeInOut(duration: 0.3)) { errorToast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) { errorToast = nil }
            }
        }
    }

    private func doctorAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Image(systemName: "stethoscope")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Models

struct DoctorMessage: Identifiable, Hashable {
    enum Role: String { case user, assistant }
    let id: UUID = UUID()
    let role: Role
    let content: String
    let createdAt: Date = Date()
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    let message: DoctorMessage

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 40)
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: PrecisionCalTheme.terracotta.opacity(0.3), radius: 10, x: 0, y: 6)
                    }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: "stethoscope")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                doctorBubbleContent(parse(message.content))
                Spacer(minLength: 24)
            }
        }
    }

    private struct ParsedReply {
        let body: String
        let sources: [String]
        let disclaimer: String?
    }

    private func parse(_ raw: String) -> ParsedReply {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Pull off trailing disclaimer line if present.
        var working = trimmed
        var disclaimer: String? = nil
        let lines = working.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        if let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           last.lowercased().contains("educational") && last.lowercased().contains("not medical advice") {
            disclaimer = last.trimmingCharacters(in: .whitespaces)
            if let range = working.range(of: last, options: .backwards) {
                working = String(working[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Split off Sources: section.
        var sources: [String] = []
        if let srcRange = working.range(of: "Sources:", options: [.caseInsensitive, .backwards]) {
            let srcBlock = working[srcRange.upperBound...]
            sources = srcBlock
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            working = String(working[..<srcRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ParsedReply(body: working, sources: sources, disclaimer: disclaimer)
    }

    @ViewBuilder
    private func doctorBubbleContent(_ parsed: ParsedReply) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(highlightCitations(parsed.body))
                .font(.system(size: 15))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
            if !parsed.sources.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("SOURCES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                    }
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                    ForEach(parsed.sources, id: \.self) { src in
                        Text(src)
                            .font(.system(size: 11))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                            .lineSpacing(1)
                            .textSelection(.enabled)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PrecisionCalTheme.terracotta.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PrecisionCalTheme.terracotta.opacity(0.18), lineWidth: 0.8)
                        )
                }
            }
            if let disclaimer = parsed.disclaimer {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                        .padding(.top, 1)
                    Text(disclaimer)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                        .italic()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }

    private func highlightCitations(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        guard let regex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]") else { return attr }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let token = ns.substring(with: match.range)
            if let range = attr.range(of: token, options: .backwards) {
                attr[range].font = .system(size: 11, weight: .bold).monospacedDigit()
                attr[range].foregroundColor = PrecisionCalTheme.terracotta
                attr[range].baselineOffset = 3
            }
        }
        return attr
    }
}

private struct TypingBubble: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "stethoscope")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(PrecisionCalTheme.terracotta.opacity(phase == i ? 0.95 : 0.35))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.15 : 1)
                        .animation(.easeInOut(duration: 0.35), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1)
                    )
            }

            Spacer(minLength: 24)
        }
        .onAppear {
            startCycle()
        }
    }

    private func startCycle() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(380))
                phase = (phase + 1) % 3
            }
        }
    }
}
