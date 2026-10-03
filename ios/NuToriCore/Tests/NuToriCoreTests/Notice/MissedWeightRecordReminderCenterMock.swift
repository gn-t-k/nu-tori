import Foundation
import NuToriCore
import Synchronization

/// メモリの通知の置き場。予約した通知と、通知センターに残った通知を持ち、許可を求めた回数を数える
final class MissedWeightRecordReminderCenterMock: MissedWeightRecordReminderCenter, Sendable {
    /// 予約してある通知の ID
    var scheduled: Set<UUID> {
        storage.withLock { $0.scheduled }
    }

    var delivered: Set<UUID> {
        storage.withLock { $0.delivered }
    }

    var permissionRequestCount: Int {
        storage.withLock { $0.permissionRequestCount }
    }

    /// `scheduled` は、前に予約してあった通知の ID
    static func ok(
        permission: NotificationPermission = .permitted,
        grantsPermission: Bool = true,
        scheduled: [UUID] = [],
        delivered: [UUID] = []
    ) -> MissedWeightRecordReminderCenterMock {
        MissedWeightRecordReminderCenterMock(
            permission: permission, permissionRequest: .answers(granted: grantsPermission),
            scheduleFailure: nil, scheduled: scheduled, delivered: delivered)
    }

    /// 予約が失敗する置き場
    static func error(_ error: any Error) -> MissedWeightRecordReminderCenterMock {
        MissedWeightRecordReminderCenterMock(
            permission: .permitted, permissionRequest: .answers(granted: true),
            scheduleFailure: error,
            scheduled: [], delivered: [])
    }

    /// まだ許可を求めておらず、求めると失敗する置き場
    static func permissionRequestError(_ error: any Error) -> MissedWeightRecordReminderCenterMock {
        MissedWeightRecordReminderCenterMock(
            permission: .notYetRequested, permissionRequest: .fails(error), scheduleFailure: nil,
            scheduled: [], delivered: [])
    }

    func permission() async -> NotificationPermission {
        storage.withLock { $0.permission }
    }

    func requestPermission() async throws -> Bool {
        try storage.withLock {
            $0.permissionRequestCount += 1
            switch $0.permissionRequest {
            case .answers(let granted):
                $0.permission = granted ? .permitted : .notPermitted
                return granted
            case .fails(let error):
                throw error
            }
        }
    }

    func scheduledIds() async -> [UUID] {
        storage.withLock { Array($0.scheduled) }
    }

    func deliveredIds() async -> [UUID] {
        storage.withLock { Array($0.delivered) }
    }

    func schedule(_ reminder: MissedWeightRecordReminder) async throws {
        try storage.withLock {
            if let failure = $0.scheduleFailure {
                throw failure
            }
            $0.scheduled.insert(reminder.id)
        }
    }

    func removeScheduled(ids: [UUID]) async {
        storage.withLock { $0.scheduled.subtract(ids) }
    }

    func removeDelivered(ids: [UUID]) async {
        storage.withLock { $0.delivered.subtract(ids) }
    }

    private enum PermissionRequestOutcome {
        case answers(granted: Bool)
        case fails(any Error)
    }

    private struct Storage {
        var permission: NotificationPermission
        let permissionRequest: PermissionRequestOutcome
        let scheduleFailure: (any Error)?
        var scheduled: Set<UUID>
        var delivered: Set<UUID>
        var permissionRequestCount = 0
    }

    private let storage: Mutex<Storage>

    private init(
        permission: NotificationPermission,
        permissionRequest: PermissionRequestOutcome,
        scheduleFailure: (any Error)?,
        scheduled: [UUID],
        delivered: [UUID]
    ) {
        storage = Mutex(
            Storage(
                permission: permission,
                permissionRequest: permissionRequest,
                scheduleFailure: scheduleFailure,
                scheduled: Set(scheduled),
                delivered: Set(delivered)
            ))
    }
}
