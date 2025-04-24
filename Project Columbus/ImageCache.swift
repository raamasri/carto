//
//  ImageCache.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/22/25.
//

import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let memory = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default

    private lazy var diskDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("ProfileImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    func image(forKey key: String) -> UIImage? {
        if let image = memory.object(forKey: key as NSString) {
            return image
        }
        let fileURL = diskDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    func insertImage(_ image: UIImage, forKey key: String) {
        memory.setObject(image, forKey: key as NSString)
        let fileURL = diskDirectory.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    func clearCache() {
        // Clear in-memory cache
        memory.removeAllObjects()
        // Clear disk cache
        try? fileManager.removeItem(at: diskDirectory)
        // Recreate directory
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }
}
