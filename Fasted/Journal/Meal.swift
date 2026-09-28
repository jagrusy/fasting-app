import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct MealAttachment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let thumbnailFilename: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        filename: String,
        thumbnailFilename: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.createdAt = createdAt
    }
}

public struct MealEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let mealTime: Date
    public let notes: String?
    public let attachments: [MealAttachment]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        mealTime: Date,
        notes: String? = nil,
        attachments: [MealAttachment] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mealTime = mealTime
        self.notes = notes
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var hasPhoto: Bool {
        !attachments.isEmpty
    }

    public var displayTitle: String {
        if let notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }
        return "Meal"
    }
}

public struct MealDraft: Equatable {
    public var mealTime: Date
    public var notes: String?
    #if canImport(UIKit)
    public var image: UIImage?
    #endif

    #if canImport(UIKit)
    public init(mealTime: Date = Date(), notes: String? = nil, image: UIImage? = nil) {
        self.mealTime = mealTime
        self.notes = notes
        self.image = image
    }
    #else
    public init(mealTime: Date = Date(), notes: String? = nil) {
        self.mealTime = mealTime
        self.notes = notes
    }
    #endif

    public var isValid: Bool {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        #if canImport(UIKit)
        let hasImage = image != nil
        return hasText || hasImage
        #else
        return hasText
        #endif
    }
}

public enum MealError: LocalizedError, Equatable {
    case invalidDraft
    case imageSaveFailed
    case notFound
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDraft:
            return "Please provide a photo or a note to save your meal."
        case .imageSaveFailed:
            return "Could not save meal photo to disk."
        case .notFound:
            return "Meal record could not be found."
        case .persistenceFailed(let reason):
            return "Failed to save meal: \(reason)"
        }
    }
}
