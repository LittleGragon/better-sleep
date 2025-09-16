import UIKit
import SwiftUI
import HealthKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let healthStore = HKHealthStore()
        let sleepDataManager = SleepDataManager(healthStore: healthStore)
        let audioRecorder = AudioRecorder()
        let audioClassifier = AudioClassifier()
        let recordingManager = RecordingManager(audioRecorder: audioRecorder, audioClassifier: audioClassifier)
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(
            rootView: ContentView(
                sleepDataManager: sleepDataManager,
                recordingManager: recordingManager
            )
        )
        window?.makeKeyAndVisible()
        
        return true
    }
}