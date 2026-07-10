import SwiftUI
import SwiftData

extension ChatMessage: Identifiable {}

/// "Ask anything" coach. Answers are grounded in the user's own data
/// (AppContextBuilder) plus long-term memories (MemoryService) — free via
/// the on-device model when available, backend otherwise.
struct CoachChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    /// Starter prompts shown before the first message — three taps beats
    /// a blank page.
    private static let suggestions = [
        "How am I doing this week?",
        "What should I eat for dinner tonight?",
        "Am I on track for my goal weight?",
        "Suggest tomorrow's workout",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            if messages.isEmpty {
                                emptyState
                            }
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isThinking {
                                ThinkingBubble()
                            }
                            if let errorText {
                                Text(errorText)
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.error)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
            .background(Theme.Color.background)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Clear conversation", systemImage: "trash", role: .destructive) {
                            clearConversation()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Color.accent)
                .padding(.top, Theme.Spacing.xxl)
            Text("Ask me anything")
                .font(Theme.Font.display28)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("I know your workouts, meals, and goals —\nso answers are about *you*, not generic advice.")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button {
                        send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(Theme.Font.body17)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Spacing.sm)
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField("Ask your coach…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(Theme.Spacing.sm)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Theme.Color.accent : Theme.Color.textTertiary)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.background)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }

        let history = messages // capture before inserting
        context.insert(ChatMessage(role: "user", text: question))
        try? context.save()
        draft = ""
        errorText = nil
        isThinking = true
        Haptics.light()

        Task {
            defer { isThinking = false }
            do {
                let reply = try await container.ai.askCoach(question: question, history: history)
                context.insert(ChatMessage(role: "assistant", text: reply))
                try? context.save()
            } catch {
                errorText = container.ai.isTextAIAvailable
                    ? "Couldn't reach the coach — check your connection and try again."
                    : "AI needs either an Apple Intelligence device or a signed-in account (Profile tab)."
            }
        }
    }

    private func clearConversation() {
        for message in messages { context.delete(message) }
        try? context.save()
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }
            Text(message.text)
                .font(Theme.Font.body17)
                .foregroundStyle(message.isUser ? Theme.Color.onAccent : Theme.Color.textPrimary)
                .padding(Theme.Spacing.sm)
                .background(
                    message.isUser ? Theme.Color.accent : Theme.Color.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.medium)
                )
            if !message.isUser { Spacer(minLength: 48) }
        }
    }
}

private struct ThinkingBubble: View {
    @State private var phase = 0.0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.Color.textTertiary)
                        .frame(width: 7, height: 7)
                        .opacity(phase == Double(index) ? 1 : 0.35)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            Spacer(minLength: 48)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                phase = (phase + 1).truncatingRemainder(dividingBy: 3)
            }
        }
        .accessibilityLabel("Coach is thinking")
    }
}
