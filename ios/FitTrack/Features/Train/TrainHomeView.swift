import SwiftUI
import SwiftData

extension Workout: Identifiable {}
extension Routine: Identifiable {}

/// Train tab home: continue/start actions up top, routine cards (tap =
/// start, menu = edit/reorder/delete), then history and per-exercise
/// progress. Pre-built routines start with everything pre-filled — in the
/// gym it's one tap to begin, then just log reps and weight.
struct TrainHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.position) private var routines: [Routine]
    @Query(WorkoutStarter.lastFinishedWorkoutDescriptor) private var lastFinishedWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.finishedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var inProgressWorkouts: [Workout]

    @State private var startedWorkout: Workout?
    @State private var editingRoutine: Routine?
    @State private var showingNewRoutine = false

    private var visibleRoutines: [Routine] {
        routines.filter { $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    quickStart

                    routinesSection

                    linksSection
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewRoutine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New routine")
                }
            }
            .fullScreenCover(item: $startedWorkout) { workout in
                WorkoutSessionView(workout: workout)
            }
            .sheet(isPresented: $showingNewRoutine) {
                RoutineEditorView()
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
            }
        }
    }

    // MARK: - Quick start

    private var quickStart: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let inProgress = inProgressWorkouts.first {
                Button {
                    startedWorkout = inProgress
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue \(inProgress.name.isEmpty ? "workout" : inProgress.name)")
                                .font(Theme.Font.bodyEmphasized17)
                            Text("Started \(inProgress.startedAt.formatted(date: .omitted, time: .shortened))")
                                .font(Theme.Font.caption13)
                                .opacity(0.8)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Theme.Color.onAccent)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        startedWorkout = WorkoutStarter.start(from: nil, context: context)
                    } label: {
                        Label("Start empty", systemImage: "plus.circle.fill")
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .buttonStyle(.plain)

                    if let last = lastFinishedWorkouts.first {
                        Button {
                            startedWorkout = WorkoutStarter.repeatWorkout(last, context: context)
                        } label: {
                            Label("Repeat last", systemImage: "arrow.clockwise")
                                .font(Theme.Font.bodyEmphasized17)
                                .foregroundStyle(Theme.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Routines

    @ViewBuilder
    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("My routines")
                .font(Theme.Font.title22)
                .foregroundStyle(Theme.Color.textPrimary)

            if visibleRoutines.isEmpty {
                Card {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Build workouts ahead of time")
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("Pre-build as many as you want. In the gym, one tap starts the whole session with your last weights filled in.")
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Create a routine") { showingNewRoutine = true }
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.accent)
                            .padding(.top, Theme.Spacing.xxs)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(visibleRoutines) { routine in
                    RoutineCard(
                        routine: routine,
                        onStart: { startedWorkout = WorkoutStarter.start(from: routine, context: context) },
                        onEdit: { editingRoutine = routine },
                        onDelete: { delete(routine) }
                    )
                }
            }
        }
    }

    private var linksSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            NavigationLink {
                WorkoutHistoryView()
            } label: {
                linkRow(icon: "clock.arrow.circlepath", title: "Workout history", subtitle: "Every session, stats, save as routine")
            }
            NavigationLink {
                ExerciseProgressView()
            } label: {
                linkRow(icon: "chart.line.uptrend.xyaxis", title: "Exercise progress", subtitle: "Search any lift, see your whole journey")
            }
        }
        .buttonStyle(.plain)
    }

    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
        Card {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(subtitle)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Color.textTertiary)
            }
        }
    }

    private func delete(_ routine: Routine) {
        routine.markDeleted()
        try? context.save()
    }
}

private struct RoutineCard: View {
    let routine: Routine
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Card {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name)
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("\(routine.items.count) exercises")
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer()

                Button(action: onStart) {
                    Text("Start")
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.onAccent)
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(height: 40)
                        .background(Theme.Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 36, height: 40)
                }
                .accessibilityLabel("Routine options")
            }
        }
    }
}
