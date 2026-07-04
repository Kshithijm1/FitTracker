import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "circle.grid.2x2.fill") {
                TodayView()
            }
            Tab("Train", systemImage: "dumbbell.fill") {
                TrainHomeView()
            }
            Tab("Nutrition", systemImage: "fork.knife") {
                NutritionHomeView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressHomeView()
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tint(Theme.Color.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
