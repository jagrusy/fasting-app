import Foundation
import CoreData

extension FastManager {
    public func seedMockDataForScreenshots(progress: Double = 0.8) {
        clearAllFastingData()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Seed 14 days of completed fasts for a gorgeous streak
        for dayOffset in (1...14).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let completed = Fast(context: viewContext)
            completed.id = UUID()
            completed.startDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day)
            completed.endDate = calendar.date(byAdding: .hour, value: 16, to: completed.startDate ?? day)
            completed.targetDuration = 16 * 3600
            completed.protocolType = "16:8"
            completed.isCompleted = true
            completed.createdAt = completed.startDate
            completed.updatedAt = completed.endDate
        }

        // Active fast
        let active = Fast(context: viewContext)
        active.id = UUID()
        active.startDate = Date().addingTimeInterval(-progress * 16 * 3600)
        active.targetDuration = 16 * 3600
        active.protocolType = "16:8"
        active.isCompleted = false
        active.createdAt = active.startDate
        active.updatedAt = Date()

        try? viewContext.save()
        refresh()
    }
}
