import Foundation
import ActivityKit

public struct RestTimerActivityAttributes: ActivityAttributes, Sendable { // <-- ADD SENDABLE HERE
    public struct ContentState: Codable, Hashable, Sendable {    // <-- ADD SENDABLE HERE
        public var endsAt: Date
        
        public init(endsAt: Date) {
            self.endsAt = endsAt
        }
    }

    public var exerciseName: String
    
    public init(exerciseName: String) {
        self.exerciseName = exerciseName
    }
}
