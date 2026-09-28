import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class MealPhotoStorage: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = appSupport.appendingPathComponent("Fasted/MealPhotos", isDirectory: true)
        }
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func fileURL(for filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    #if canImport(UIKit)
    /// Saves a photo and its thumbnail to disk, returning filenames.
    public func save(
        image: UIImage,
        id: UUID = UUID()
    ) throws -> (filename: String, thumbnailFilename: String) {
        createDirectoryIfNeeded()

        let filename = "\(id.uuidString).jpg"
        let thumbFilename = "\(id.uuidString)_thumb.jpg"

        let fileURL = self.fileURL(for: filename)
        let thumbURL = self.fileURL(for: thumbFilename)

        // Bounded full image: max 1920px
        let fullImage = resize(image: image, maxDimension: 1920)
        guard let fullData = fullImage.jpegData(compressionQuality: 0.85) else {
            throw MealError.imageSaveFailed
        }

        // Bounded thumbnail: max 300px
        let thumbImage = resize(image: image, maxDimension: 300)
        guard let thumbData = thumbImage.jpegData(compressionQuality: 0.80) else {
            throw MealError.imageSaveFailed
        }

        do {
            try fullData.write(to: fileURL, options: .atomic)
            try thumbData.write(to: thumbURL, options: .atomic)
            return (filename, thumbFilename)
        } catch {
            // Clean up partial files on write error
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: thumbURL)
            throw MealError.imageSaveFailed
        }
    }

    public func loadImage(filename: String) -> UIImage? {
        let url = fileURL(for: filename)
        return UIImage(contentsOfFile: url.path)
    }

    private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    public func delete(filename: String, thumbnailFilename: String? = nil) {
        let url = fileURL(for: filename)
        try? FileManager.default.removeItem(at: url)

        if let thumbnailFilename {
            let thumbURL = fileURL(for: thumbnailFilename)
            try? FileManager.default.removeItem(at: thumbURL)
        }
    }

    /// Deletes any files in the photos directory that are not in the referenced set.
    public func cleanupOrphans(referencedFilenames: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for fileURL in contents {
            let name = fileURL.lastPathComponent
            if !referencedFilenames.contains(name) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
