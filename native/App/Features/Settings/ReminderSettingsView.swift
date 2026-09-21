import SwiftUI
import UserNotifications
import UIKit

struct ReminderSettingsView: View {
    @AppStorage(ReminderPreferenceKeys.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderPreferenceKeys.solarTermEnabled) private var solarTermEnabled = false
    @AppStorage(ReminderPreferenceKeys.hour) private var hour = 8
    @AppStorage(ReminderPreferenceKeys.minute) private var minute = 0
    @State private var permissionLabel = "正在读取通知权限…"
    @State private var message: String?
    @State private var offersSettings = false

    var body: some View {
        Form {
            Section {
                Toggle("晨间日签", isOn: Binding(
                    get: { dailyEnabled },
                    set: updateDailyEnabled
                ))
                if dailyEnabled {
                    DatePicker(
                        "提醒时间",
                        selection: Binding(get: { selectedTime }, set: updateTime),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("清晨的一张纸")
            } footer: {
                Text("在你选择的本地时间轻轻提醒。关闭后只取消有时创建的晨间提醒。")
            }

            Section {
                Toggle("二十四节气", isOn: Binding(
                    get: { solarTermEnabled },
                    set: updateSolarTermEnabled
                ))
            } header: {
                Text("随四时流转")
            } footer: {
                Text("按太阳视黄经的近似交节时刻安排未来二十四个节气。内容用于传统节气文化与日常自我照料，不构成医疗建议。")
            }

            Section("系统权限") {
                Label(permissionLabel, systemImage: "bell.badge")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("提醒")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPermissionLabel() }
        .alert("提醒", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil; offersSettings = false } }
        )) {
            if offersSettings {
                Button("打开系统设置") { openSystemSettings() }
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var selectedTime: Date {
        Calendar.current.date(from: DateComponents(
            calendar: Calendar.current,
            timeZone: .current,
            year: 2001,
            month: 1,
            day: 1,
            hour: hour,
            minute: minute
        )) ?? Date()
    }

    private func updateDailyEnabled(_ enabled: Bool) {
        dailyEnabled = enabled
        Task {
            let result = await ReminderService.shared.setDailyEnabled(enabled, hour: hour, minute: minute)
            await handle(result, preference: $dailyEnabled)
        }
    }

    private func updateSolarTermEnabled(_ enabled: Bool) {
        solarTermEnabled = enabled
        Task {
            let result = await ReminderService.shared.setSolarTermEnabled(enabled)
            await handle(result, preference: $solarTermEnabled)
        }
    }

    private func updateTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? 8
        minute = components.minute ?? 0
        Task {
            let result = await ReminderService.shared.updateDailyTime(hour: hour, minute: minute)
            await handle(result, preference: $dailyEnabled)
        }
    }

    @MainActor
    private func handle(_ result: ReminderUpdateResult, preference: Binding<Bool>) async {
        switch result {
        case .enabled, .disabled:
            break
        case .denied:
            preference.wrappedValue = false
            offersSettings = true
            message = "通知权限未开启。你可以在系统设置中允许“有时”发送提醒。"
        case .failed(let text):
            message = text
        }
        await refreshPermissionLabel()
    }

    @MainActor
    private func refreshPermissionLabel() async {
        switch await ReminderService.shared.authorizationStatus() {
        case .authorized: permissionLabel = "通知已允许"
        case .provisional: permissionLabel = "通知以静默方式送达"
        case .ephemeral: permissionLabel = "通知暂时允许"
        case .denied: permissionLabel = "通知已关闭"
        case .notDetermined: permissionLabel = "开启提醒时再询问"
        @unknown default: permissionLabel = "通知状态未知"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
