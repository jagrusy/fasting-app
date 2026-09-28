import XCTest
import CoreData
import UserNotifications
@testable import Fasted

@MainActor
final class FastManagerPersistenceFailureTests: XCTestCase {
    private enum InjectedFailure: Error {
        case read
        case save
    }

    private final class FailureSwitch {
        var failReads = false
        var failSaves = false
    }

    private final class NotificationSpy {
        var requests: [String: UNNotificationRequest] = [:]
        var changes = 0
    }

    private struct Fixture {
        let notifications: NotificationSpy
        let manager: FastManager
        let coordinator: AppGroupCoordinator
        let failures: FailureSwitch
        let storeURL: URL
    }

    private var storeURLs: [URL] = []
    private var defaultsSuiteNames: [String] = []
    private var commandDirectories: [URL] = []
    private var persistenceControllers: [PersistenceController] = []

    override func tearDownWithError() throws {
        for controller in persistenceControllers {
            let coordinator = controller.container.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        persistenceControllers = []
        for name in defaultsSuiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        for directory in commandDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        for url in storeURLs {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + "-shm")
            try? FileManager.default.removeItem(atPath: url.path + "-wal")
        }
        storeURLs = []
        defaultsSuiteNames = []
        commandDirectories = []
        try super.tearDownWithError()
    }

    func testFailedStartReturnsNoFastAndDoesNotReachDiskOrSnapshot() throws {
        let fixture = makeFixture()
        let before = fixture.coordinator.readSnapshot()
        let notificationChanges = fixture.notifications.changes
        fixture.failures.failSaves = true

        let result = fixture.manager.startFast(startDate: Date().addingTimeInterval(-60))

        XCTAssertNil(result)
        XCTAssertNil(fixture.manager.activeFast)
        XCTAssertNotNil(fixture.manager.operationError)
        XCTAssertEqual(fixture.coordinator.readSnapshot(), before)
        XCTAssertEqual(fixture.notifications.changes, notificationChanges)
        XCTAssertEqual(try reopenedFasts(at: fixture.storeURL).count, 0)
    }

    func testFailedEndPreservesActiveFastOnDiskAndLeavesSnapshotUntouched() throws {
        let fixture = makeFixture()
        let fast = try XCTUnwrap(fixture.manager.startFast(startDate: Date().addingTimeInterval(-3600)))
        let before = fixture.coordinator.readSnapshot()
        let notificationChanges = fixture.notifications.changes
        fixture.failures.failSaves = true

        XCTAssertFalse(fixture.manager.endFast(endDate: Date()))

        XCTAssertEqual(fixture.manager.activeFast, fast)
        XCTAssertNil(fast.endDate)
        XCTAssertEqual(fixture.coordinator.readSnapshot(), before)
        XCTAssertEqual(fixture.notifications.changes, notificationChanges)
        let reopened = try XCTUnwrap(reopenedFasts(at: fixture.storeURL).first)
        XCTAssertNil(reopened.endDate)
    }

    func testFailedCompletedEditRestoresCommittedDatesAfterReopen() throws {
        let fixture = makeFixture()
        let originalStart = Date().addingTimeInterval(-7200)
        let originalEnd = Date().addingTimeInterval(-3600)
        let fast = try XCTUnwrap(fixture.manager.startFast(startDate: originalStart))
        XCTAssertTrue(fixture.manager.endFast(endDate: originalEnd))
        fixture.failures.failSaves = true

        XCTAssertFalse(
            fixture.manager.updateCompletedFast(
                fast,
                startDate: originalStart.addingTimeInterval(-600),
                endDate: originalEnd.addingTimeInterval(600)
            )
        )

        XCTAssertEqual(fast.startDate, originalStart)
        XCTAssertEqual(fast.endDate, originalEnd)
        let reopened = try XCTUnwrap(reopenedFasts(at: fixture.storeURL).first)
        XCTAssertEqual(reopened.startDate, originalStart)
        XCTAssertEqual(reopened.endDate, originalEnd)
    }

    func testFailedActiveEditRestoresCommittedStartAndGoalAfterReopen() throws {
        let fixture = makeFixture()
        let originalStart = Date().addingTimeInterval(-3600)
        let fast = try XCTUnwrap(
            fixture.manager.startFast(
                startDate: originalStart,
                targetDuration: 16 * 3600,
                protocolType: "16:8"
            )
        )
        fixture.failures.failSaves = true

        XCTAssertFalse(
            fixture.manager.updateActiveFast(
                startDate: originalStart.addingTimeInterval(-600),
                targetDuration: 18 * 3600,
                protocolType: "18:6"
            )
        )

        XCTAssertEqual(fast.startDate, originalStart)
        XCTAssertEqual(fast.targetDuration, 16 * 3600)
        XCTAssertEqual(fast.protocolType, "16:8")
        let reopened = try XCTUnwrap(reopenedFasts(at: fixture.storeURL).first)
        XCTAssertEqual(reopened.startDate, originalStart)
        XCTAssertEqual(reopened.targetDuration, 16 * 3600)
        XCTAssertEqual(reopened.protocolType, "16:8")
    }

    func testFailedSettingsWritesRestoreCommittedValuesAfterReopen() throws {
        let fixture = makeFixture()
        let originalProtocol = try XCTUnwrap(fixture.manager.userSettings?.selectedProtocol)
        let originalNotifications = fixture.manager.userSettings?.notificationsEnabled
        fixture.failures.failSaves = true

        XCTAssertFalse(fixture.manager.updateSelectedProtocol("18:6"))
        XCTAssertEqual(fixture.manager.userSettings?.selectedProtocol, originalProtocol)
        XCTAssertFalse(
            fixture.manager.updateNotificationSchedule(
                enabled: true,
                schedule: fixture.manager.notificationSchedule
            )
        )
        XCTAssertEqual(fixture.manager.userSettings?.notificationsEnabled, originalNotifications)

        let reopened = PersistenceController(storeURL: fixture.storeURL)
        persistenceControllers.append(reopened)
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        let settings = try XCTUnwrap(reopened.container.viewContext.fetch(request).first)
        XCTAssertEqual(settings.selectedProtocol, originalProtocol)
        XCTAssertEqual(settings.notificationsEnabled, originalNotifications)
    }

    func testFailedProtocolRetargetRollsBackSettingsAndActiveFastTogether() throws {
        let fixture = makeFixture()
        let fast = try XCTUnwrap(
            fixture.manager.startFast(
                startDate: Date().addingTimeInterval(-3600),
                targetDuration: 16 * 3600,
                protocolType: "16:8"
            )
        )
        fixture.failures.failSaves = true

        XCTAssertFalse(fixture.manager.updateSelectedProtocol("18:6", retargetActiveFast: true))

        XCTAssertEqual(fixture.manager.userSettings?.selectedProtocol, "16:8")
        XCTAssertEqual(fast.protocolType, "16:8")
        XCTAssertEqual(fast.targetDuration, 16 * 3600)
        let reopened = try XCTUnwrap(reopenedFasts(at: fixture.storeURL).first)
        XCTAssertEqual(reopened.protocolType, "16:8")
        XCTAssertEqual(reopened.targetDuration, 16 * 3600)
    }

    func testValidationFetchFailureIsRejectedAndPreservesCommittedHistory() throws {
        let fixture = makeFixture()
        let committedStart = Date().addingTimeInterval(-7200)
        let committedEnd = Date().addingTimeInterval(-3600)
        _ = try XCTUnwrap(fixture.manager.startFast(startDate: committedStart))
        XCTAssertTrue(fixture.manager.endFast(endDate: committedEnd))
        fixture.failures.failReads = true

        let result = fixture.manager.validateInterval(
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date().addingTimeInterval(-900)
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(
            result.message,
            "Solstice couldn't verify this time against your history. Please try again."
        )
        XCTAssertNotNil(fixture.manager.operationError)
        let reopened = try XCTUnwrap(reopenedFasts(at: fixture.storeURL).first)
        XCTAssertEqual(reopened.startDate, committedStart)
        XCTAssertEqual(reopened.endDate, committedEnd)
    }

}

extension FastManagerPersistenceFailureTests {
    func testPostCommitSnapshotFailureDoesNotClaimSavedDataIsUnchanged() throws {
        let fixture = makeFixture()
        _ = try XCTUnwrap(fixture.manager.startFast(startDate: Date().addingTimeInterval(-3600)))
        fixture.failures.failReads = true
        let end = Date()

        XCTAssertTrue(fixture.manager.endFast(endDate: end))
        XCTAssertNil(fixture.manager.activeFast)
        let error = try XCTUnwrap(fixture.manager.operationError)
        XCTAssertFalse(error.message.contains("unchanged"))
        XCTAssertEqual(try reopenedFasts(at: fixture.storeURL).first?.endDate, end)
    }

    func testDeleteFailureKeepsFastAndSnoozeThenSuccessfulDeleteClearsBoth() throws {
        let fixture = makeFixture()
        let fast = try XCTUnwrap(fixture.manager.startFast(startDate: Date().addingTimeInterval(-3600)))
        let identifier = try XCTUnwrap(fast.id)
        let key = fixture.manager.snoozeOffsetKey(for: identifier)
        fixture.manager.defaults.set(1800, forKey: key)
        let changes = fixture.notifications.changes
        fixture.failures.failSaves = true
        XCTAssertFalse(fixture.manager.deleteFast(fast))
        XCTAssertEqual(try reopenedFasts(at: fixture.storeURL).count, 1)
        XCTAssertEqual(fixture.manager.defaults.double(forKey: key), 1800)
        XCTAssertEqual(fixture.notifications.changes, changes)

        fixture.failures.failSaves = false
        XCTAssertTrue(fixture.manager.deleteFast(fast))
        XCTAssertEqual(try reopenedFasts(at: fixture.storeURL).count, 0)
        XCTAssertNil(fixture.manager.defaults.object(forKey: key))
    }

    func testRetargetReschedulesRecurringRemindersAndDayMilestones() throws {
        let fixture = makeFixture()
        _ = try XCTUnwrap(fixture.manager.startFast(startDate: Date().addingTimeInterval(-60)))
        XCTAssertTrue(fixture.manager.updateNotificationSchedule(enabled: true, schedule: .default))
        let identifiers = Set(fixture.notifications.requests.keys)
        XCTAssertFalse(identifiers.contains(NotificationManager.dayMilestoneIdentifier(forDay: 2)))

        XCTAssertTrue(fixture.manager.updateSelectedProtocol("72h", retargetActiveFast: true))

        XCTAssertNotNil(fixture.notifications.requests[NotificationManager.dayMilestoneIdentifier(forDay: 2)])
        let goal = try XCTUnwrap(fixture.manager.activeFastGoalDate())
        let reminders = fixture.notifications.requests.values.filter { $0.identifier.hasPrefix("recurring_start") }
        XCTAssertFalse(reminders.isEmpty)
        for request in reminders {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            let next = try XCTUnwrap(trigger.nextTriggerDate())
            XCTAssertGreaterThan(next, goal)
        }
    }

}

extension FastManagerPersistenceFailureTests {
    private func makeFixture() -> Fixture {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fast-manager-failure-\(UUID().uuidString).sqlite")
        storeURLs.append(storeURL)

        let controller = PersistenceController(storeURL: storeURL)
        persistenceControllers.append(controller)
        let context = controller.container.viewContext
        let failures = FailureSwitch()
        var persistence = FastManagerPersistence(context: context)
        let liveFetchFasts = persistence.fetchFasts
        let liveFetchSettings = persistence.fetchSettings
        let liveSave = persistence.save
        persistence.fetchFasts = { request in
            if failures.failReads { throw InjectedFailure.read }
            return try liveFetchFasts(request)
        }
        persistence.fetchSettings = { request in
            if failures.failReads { throw InjectedFailure.read }
            return try liveFetchSettings(request)
        }
        persistence.save = {
            if failures.failSaves { throw InjectedFailure.save }
            try liveSave()
        }

        let suiteName = "FastManagerPersistenceFailureTests.\(UUID().uuidString)"
        defaultsSuiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let commandDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fast-manager-commands-\(UUID().uuidString)", isDirectory: true)
        commandDirectories.append(commandDirectory)
        let coordinator = AppGroupCoordinator(
            userDefaults: defaults,
            commandsDirectory: commandDirectory
        )
        let notifications = NotificationSpy()
        let manager = FastManager(
            context: context,
            notificationManager: NotificationManager(delivery: notificationDelivery(for: notifications)),
            defaults: defaults,
            coordinator: coordinator,
            persistence: persistence,
            effects: FastManagerEffects(syncWatch: { _ in }, requestReview: { _, _ in }),
            observeExternalCommands: false
        )
        return Fixture(
            notifications: notifications,
            manager: manager,
            coordinator: coordinator,
            failures: failures,
            storeURL: storeURL
        )
    }

    private func notificationDelivery(for notifications: NotificationSpy) -> NotificationDelivery {
        NotificationDelivery(
            add: { request, completion in
                notifications.requests[request.identifier] = request
                notifications.changes += 1
                completion(nil)
            },
            remove: { identifiers in
                identifiers.forEach { notifications.requests.removeValue(forKey: $0) }
                notifications.changes += 1
            },
            register: { _ in },
            requestAuthorization: { $0(false, nil) }
        )
    }

    private func reopenedFasts(at storeURL: URL) throws -> [Fast] {
        let reopened = PersistenceController(storeURL: storeURL)
        persistenceControllers.append(reopened)
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        return try reopened.container.viewContext.fetch(request)
    }
}
