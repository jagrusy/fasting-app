import XCTest
import CoreData
@testable import Fasted

@MainActor
final class PendingCommandReconciliationTests: XCTestCase {
    private var testDefaults: UserDefaults?
    private var coordinator: AppGroupCoordinator?
    private var persistenceController: PersistenceController?
    private var notificationManager: NotificationManager?
    private var fastManager: FastManager?
    private var testSuiteName: String?

    override func setUp() {
        super.setUp()
        let suiteName = "test.solstice.reconciliation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let coord = AppGroupCoordinator(userDefaults: defaults, appGroupId: suiteName)
        let persistence = PersistenceController(inMemory: true)
        let notif = NotificationManager.shared
        let manager = FastManager(
            context: persistence.container.viewContext,
            notificationManager: notif,
            defaults: defaults,
            coordinator: coord
        )
        self.testSuiteName = suiteName
        self.testDefaults = defaults
        self.coordinator = coord
        self.persistenceController = persistence
        self.notificationManager = notif
        self.fastManager = manager
    }

    override func tearDown() {
        if let suite = testSuiteName {
            testDefaults?.removePersistentDomain(forName: suite)
        }
        testDefaults = nil
        coordinator = nil
        persistenceController = nil
        notificationManager = nil
        fastManager = nil
        super.tearDown()
    }

    func testWidgetEnqueuesStartFastWhileAppTerminated() {
        guard let fastManager = fastManager, let coordinator = coordinator else {
            XCTFail("Setup failed")
            return
        }
        // App is terminated, fastManager is not active
        XCTAssertFalse(fastManager.isFasting)

        let startTime = Date(timeIntervalSince1970: 1700000000)

        let command = FastingActionCommand.startFast(
            startDate: startTime,
            duration: 18 * 3600,
            protocolType: "18:6"
        )
        coordinator.enqueueCommand(command)

        // Main app launches and processes pending commands
        fastManager.processPendingCommands()

        // Verify Core Data has the active fast
        XCTAssertTrue(fastManager.isFasting)
        XCTAssertEqual(fastManager.activeFast?.startDate, startTime)
        XCTAssertEqual(fastManager.activeFast?.targetDuration, 18 * 3600)
        XCTAssertEqual(fastManager.activeFast?.protocolType, "18:6")

        // Verify snapshot was published
        let snapshot = coordinator.readSnapshot()
        XCTAssertTrue(snapshot.isFasting)
        XCTAssertEqual(snapshot.startDate, startTime)
        XCTAssertEqual(snapshot.targetDuration, 18 * 3600)
        XCTAssertEqual(snapshot.protocolType, "18:6")
    }

    func testWidgetEnqueuesEndFast() {
        guard let fastManager = fastManager, let coordinator = coordinator else {
            XCTFail("Setup failed")
            return
        }
        let startTime = Date(timeIntervalSince1970: 1700000000)
        fastManager.startFast(startDate: startTime, targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertTrue(fastManager.isFasting)

        let endTime = startTime.addingTimeInterval(16 * 3600)
        coordinator.enqueueCommand(.endFast(endDate: endTime))

        fastManager.processPendingCommands()

        XCTAssertFalse(fastManager.isFasting)
        XCTAssertNil(fastManager.activeFast)

        let snapshot = coordinator.readSnapshot()
        XCTAssertFalse(snapshot.isFasting)
        XCTAssertNil(snapshot.startDate)
    }

    func testWidgetEnqueuesSnoozeFast() {
        guard let fastManager = fastManager, let coordinator = coordinator else {
            XCTFail("Setup failed")
            return
        }
        let startTime = Date(timeIntervalSince1970: 1700000000)
        fastManager.startFast(startDate: startTime, targetDuration: 16 * 3600, protocolType: "16:8")
        XCTAssertTrue(fastManager.isFasting)

        coordinator.enqueueCommand(.snoozeFast(extensionSeconds: 3600)) // 1 hour snooze
        fastManager.processPendingCommands()

        XCTAssertTrue(fastManager.isFasting)
        let snapshot = coordinator.readSnapshot()
        XCTAssertTrue(snapshot.isFasting)
        // 16 hours + 1 hour snooze = 17 hours
        XCTAssertEqual(snapshot.targetDuration, 17 * 3600)
    }

    /// A watch out of Bluetooth range queues its "end fast" via `transferUserInfo`, which is
    /// delivered whenever the phone next runs — potentially after the user already ended that fast
    /// on the phone and started a new one. Applied verbatim it would stamp an endDate *before* the
    /// new fast's startDate, leaving a negative-duration fast in History.
    func testStaleEndCommandIsDroppedRatherThanCorruptingANewerFast() {
        guard let fastManager = fastManager, let coordinator = coordinator else {
            XCTFail("Setup failed")
            return
        }
        let watchTapTime = Date().addingTimeInterval(-4 * 3600)

        // The user ended that fast on the phone and started a fresh one an hour ago.
        let newStart = Date().addingTimeInterval(-3600)
        fastManager.startFast(startDate: newStart, targetDuration: 16 * 3600, protocolType: "16:8")

        // The watch's command finally lands.
        coordinator.enqueueCommand(.endFast(endDate: watchTapTime))
        fastManager.processPendingCommands()

        XCTAssertTrue(fastManager.isFasting, "The newer fast must survive a stale end command")
        XCTAssertNil(fastManager.activeFast?.endDate)
        XCTAssertEqual(fastManager.activeFast?.startDate, newStart)
    }

    /// Commands can arrive out of order — the App Group queue and WatchConnectivity are separate
    /// delivery paths — so they are applied in tap order, not arrival order.
    func testCommandsApplyInTapOrderNotArrivalOrder() {
        guard let fastManager = fastManager, let coordinator = coordinator else {
            XCTFail("Setup failed")
            return
        }
        let startTime = Date().addingTimeInterval(-17 * 3600)
        let endTime = Date().addingTimeInterval(-3600)

        // The end arrives first, but was tapped last.
        coordinator.enqueueEnvelope(
            PendingCommandEnvelope(timestamp: endTime, command: .endFast(endDate: endTime))
        )
        coordinator.enqueueEnvelope(
            PendingCommandEnvelope(
                timestamp: startTime,
                command: .startFast(startDate: startTime, duration: 16 * 3600, protocolType: "16:8")
            )
        )

        fastManager.processPendingCommands()

        XCTAssertFalse(fastManager.isFasting, "start-then-end must settle as one completed fast")
        let request: NSFetchRequest<Fast> = Fast.fetchRequest()
        request.predicate = NSPredicate(format: "endDate != nil")
        let completed = (try? persistenceController?.container.viewContext.fetch(request)) ?? []
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed.first?.startDate, startTime)
        XCTAssertEqual(completed.first?.endDate, endTime)
    }
}
