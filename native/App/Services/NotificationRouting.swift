import SwiftUI
import UIKit
import UserNotifications

@MainActor @Observable final class NotificationRoute {
    static let shared = NotificationRoute()
    private(set) var todayRequestGeneration = 0
    private var consumedTodayRequestGeneration = 0
    var hasPendingTodayRequest: Bool {
        todayRequestGeneration != consumedTodayRequestGeneration
    }

    func enqueueToday() {
        todayRequestGeneration &+= 1
    }

    @discardableResult
    func consumeToday() -> Bool {
        guard hasPendingTodayRequest else { return false }
        consumedTodayRequestGeneration = todayRequestGeneration
        return true
    }
}

final class SujiApplicationDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.userInfo["route"] as? String == "today" {
            Task { @MainActor in NotificationRoute.shared.enqueueToday() }
        }
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
