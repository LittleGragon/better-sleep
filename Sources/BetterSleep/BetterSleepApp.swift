import SwiftUI
import HealthKit

@main
struct BetterSleepApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var sleepDataManager = SleepDataManager(healthStore: HKHealthStore())
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        WindowGroup {
            ContentView(
                sleepDataManager: sleepDataManager,
                recordingManager: recordingManager
            )
        }
    }
}