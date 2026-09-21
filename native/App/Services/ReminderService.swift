import Foundation
import SujiCore
import UserNotifications

enum ReminderPreferenceKeys {
    static let dailyEnabled = "reminders.daily.enabled"
    static let solarTermEnabled = "reminders.solar-term.enabled"
    static let hour = "reminders.daily.hour"
    static let minute = "reminders.daily.minute"
}

enum ReminderUpdateResult: Equatable {
    case enabled
    case disabled
    case denied
    case failed(String)
}

@MainActor
final class ReminderService {
    static let shared = ReminderService()

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        if defaults.object(forKey: ReminderPreferenceKeys.hour) == nil {
            defaults.set(8, forKey: ReminderPreferenceKeys.hour)
            defaults.set(0, forKey: ReminderPreferenceKeys.minute)
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Called from a user-initiated toggle. This is the only path that can ask
    /// the system for notification authorization.
    func setDailyEnabled(_ enabled: Bool, hour: Int, minute: Int) async -> ReminderUpdateResult {
        guard enabled else {
            defaults.set(false, forKey: ReminderPreferenceKeys.dailyEnabled)
            cancelDaily()
            return .disabled
        }
        guard await obtainAuthorizationFromUserAction() else {
            defaults.set(false, forKey: ReminderPreferenceKeys.dailyEnabled)
            return .denied
        }
        defaults.set(true, forKey: ReminderPreferenceKeys.dailyEnabled)
        defaults.set(hour, forKey: ReminderPreferenceKeys.hour)
        defaults.set(minute, forKey: ReminderPreferenceKeys.minute)
        return await replaceDaily(hour: hour, minute: minute)
    }

    /// Called from a user-initiated toggle. Daily and solar-term request sets
    /// use separate identifiers, so disabling either never removes the other.
    func setSolarTermEnabled(_ enabled: Bool) async -> ReminderUpdateResult {
        guard enabled else {
            defaults.set(false, forKey: ReminderPreferenceKeys.solarTermEnabled)
            await cancelSolarTerms()
            return .disabled
        }
        guard await obtainAuthorizationFromUserAction() else {
            defaults.set(false, forKey: ReminderPreferenceKeys.solarTermEnabled)
            return .denied
        }
        defaults.set(true, forKey: ReminderPreferenceKeys.solarTermEnabled)
        return await replaceSolarTerms()
    }

    func updateDailyTime(hour: Int, minute: Int) async -> ReminderUpdateResult {
        defaults.set(hour, forKey: ReminderPreferenceKeys.hour)
        defaults.set(minute, forKey: ReminderPreferenceKeys.minute)
        guard defaults.bool(forKey: ReminderPreferenceKeys.dailyEnabled) else { return .disabled }
        guard await isAuthorized else {
            defaults.set(false, forKey: ReminderPreferenceKeys.dailyEnabled)
            cancelDaily()
            return .denied
        }
        return await replaceDaily(hour: hour, minute: minute)
    }

    /// Safe for app launch and foreground refresh: it never presents a prompt.
    func refreshFromSavedPreferences() async {
        guard await isAuthorized else {
            defaults.set(false, forKey: ReminderPreferenceKeys.dailyEnabled)
            defaults.set(false, forKey: ReminderPreferenceKeys.solarTermEnabled)
            cancelDaily()
            await cancelSolarTerms()
            return
        }
        if defaults.bool(forKey: ReminderPreferenceKeys.dailyEnabled) {
            _ = await replaceDaily(
                hour: defaults.integer(forKey: ReminderPreferenceKeys.hour),
                minute: defaults.integer(forKey: ReminderPreferenceKeys.minute)
            )
        }
        if defaults.bool(forKey: ReminderPreferenceKeys.solarTermEnabled) {
            _ = await replaceSolarTerms()
        }
    }

    func cancelDaily() {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderSchedule.dailyIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [ReminderSchedule.dailyIdentifier])
    }

    func cancelSolarTerms() async {
        let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderSchedule.solarTermIdentifierPrefix) }
        let deliveredIdentifiers = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(ReminderSchedule.solarTermIdentifierPrefix) }
        let identifiers = Array(Set(pendingIdentifiers + deliveredIdentifiers))
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private var isAuthorized: Bool {
        get async {
            switch await authorizationStatus() {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        }
    }

    private func obtainAuthorizationFromUserAction() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func replaceDaily(hour: Int, minute: Int) async -> ReminderUpdateResult {
        let configuration = ReminderConfiguration(
            dailyEnabled: true,
            solarTermEnabled: false,
            hour: hour,
            minute: minute
        )
        guard let item = ReminderSchedule.makePlan(
            configuration: configuration,
            isAuthorized: true
        ).first else {
            return .failed("提醒时间无效，请重新选择。")
        }
        do {
            // Adding the same identifier atomically replaces the prior schedule.
            // If adding fails, the last valid daily request remains in place.
            try await center.add(request(for: item))
            return .enabled
        } catch {
            return .failed("晨间提醒未能保存：\(error.localizedDescription)")
        }
    }

    private func replaceSolarTerms() async -> ReminderUpdateResult {
        let configuration = ReminderConfiguration(
            dailyEnabled: false,
            solarTermEnabled: true,
            hour: 8,
            minute: 0
        )
        let items = ReminderSchedule.makePlan(
            configuration: configuration,
            isAuthorized: true
        )
        let requests = items
            .filter { $0.kind == .solarTerm }
            .map(request(for:))
        let desiredIdentifiers = Set(requests.map(\.identifier))
        let existingIdentifiers = Set(await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderSchedule.solarTermIdentifierPrefix) })
        do {
            // Install the complete desired set before deleting anything. If one
            // add fails, the previous schedule remains available for the retry.
            for request in requests {
                try await center.add(request)
            }
            let obsoleteIdentifiers = Array(existingIdentifiers.subtracting(desiredIdentifiers))
            if !obsoleteIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: obsoleteIdentifiers)
            }
            return .enabled
        } catch {
            return .failed("节气提醒未能完整保存：\(error.localizedDescription)")
        }
    }

    private func request(for item: ReminderPlanItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.userInfo = ["route": "today", "kind": item.kind.rawValue]

        let trigger: UNNotificationTrigger
        switch item.trigger {
        case .daily(let hour, let minute):
            trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
        case .date(let date):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            // Keep an astronomical crossing anchored to this absolute instant if
            // the user travels before the notification fires.
            components.timeZone = calendar.timeZone
            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
        }
        return UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
    }
}
