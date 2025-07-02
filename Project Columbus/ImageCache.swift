//
//  ImageCache.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/22/25.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

final class ImageCache: ObservableObject {
    static let shared = ImageCache()
    
    // MARK: - Cache Configuration
    private let memoryCache = NSCache<NSString, PlatformImage>()
    private let fileManager = FileManager.default
    private let diskCacheQueue = DispatchQueue(label: "com.projectcolumbus.imagecache", qos: .utility)
    
    // MARK: - Performance Settings
    private let maxMemoryCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheSize: Int = 200 * 1024 * 1024 // 200MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let compressionQuality: CGFloat = 0.8
    
    // MARK: - Cache Statistics
    @Published var cacheStats = CacheStatistics()
    
    // MARK: - Active Downloads
    private var activeDownloads: [String: Task<PlatformImage?, Error>] = [:]
    private let downloadsLock = NSLock()

    private lazy var diskDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("EnhancedImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        setupCache()
        schedulePeriodicCleanup()
    }

    // MARK: - Setup
    private func setupCache() {
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 1000
        
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
        
        print("🖼️ ImageCache: Enhanced cache initialized with \(maxMemoryCacheSize / (1024*1024))MB memory")
    }
    
    // MARK: - Primary Interface
    func image(forKey key: String) -> PlatformImage? {
        let cacheKey = sanitizeKey(key)
        
        // Check memory cache first
        if let image = memoryCache.object(forKey: cacheKey as NSString) {
            cacheStats.memoryHits += 1
            return image
        }
        
        // Check disk cache
        let fileURL = diskDirectory.appendingPathComponent(cacheKey)
        if let image = loadImageFromDisk(at: fileURL) {
            let cost = estimateImageCost(image)
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
            cacheStats.diskHits += 1
            return image
        }
        
        cacheStats.misses += 1
        return nil
    }
    
    func insertImage(_ image: PlatformImage, forKey key: String) {
        let cacheKey = sanitizeKey(key)
        let cost = estimateImageCost(image)
        
        memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
        
        diskCacheQueue.async { [weak self] in
            self?.saveImageToDisk(image, key: cacheKey)
        }
        
        cacheStats.insertions += 1
    }
    
    // MARK: - Async Loading
    func loadImage(from url: URL) async -> PlatformImage? {
        let cacheKey = sanitizeKey(url.absoluteString)
        
        // Check cache first
        if let cachedImage = image(forKey: cacheKey) {
            return cachedImage
        }
        
        // Check if already downloading
        downloadsLock.lock()
        if let existingTask = activeDownloads[cacheKey] {
            downloadsLock.unlock()
            return try? await existingTask.value
        }
        
        // Start download
        let downloadTask = Task<PlatformImage?, Error> {
            return try await downloadImage(from: url, cacheKey: cacheKey)
        }
        activeDownloads[cacheKey] = downloadTask
        downloadsLock.unlock()
        
        defer {
            downloadsLock.lock()
            activeDownloads.removeValue(forKey: cacheKey)
            downloadsLock.unlock()
        }
        
        return try? await downloadTask.value
    }
    
    private func downloadImage(from url: URL, cacheKey: String) async throws -> PlatformImage? {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = PlatformImage(data: data) else {
            throw CacheError.downloadFailed
        }
        
        insertImage(image, forKey: cacheKey)
        return image
    }
    
    // MARK: - Disk Operations
    private func loadImageFromDisk(at url: URL) -> PlatformImage? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = PlatformImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveImageToDisk(_ image: PlatformImage, key: String) {
        let fileURL = diskDirectory.appendingPathComponent(key)
        
        #if canImport(UIKit)
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return }
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else { return }
        #endif
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ ImageCache: Failed to save image to disk: \(error)")
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        memoryCache.removeAllObjects()
        
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.fileManager.removeItem(at: self.diskDirectory)
                try self.fileManager.createDirectory(at: self.diskDirectory, withIntermediateDirectories: true)
                
                DispatchQueue.main.async {
                    self.cacheStats = CacheStatistics()
                }
                
                print("🧹 ImageCache: Cache cleared successfully")
            } catch {
                print("❌ ImageCache: Failed to clear cache: \(error)")
            }
        }
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        print("🧹 ImageCache: Memory cache cleared")
    }
    
    func cleanupExpiredImages() {
        diskCacheQueue.async { [weak self] in
            self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        var filesToDelete: [URL] = []
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for fileURL in fileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < cutoffDate {
                    filesToDelete.append(fileURL)
                }
            }
            
            for fileURL in filesToDelete {
                try? fileManager.removeItem(at: fileURL)
            }
            
            DispatchQueue.main.async {
                self.cacheStats.cleanupCount += 1
            }
            
            print("🧹 ImageCache: Cleaned up \(filesToDelete.count) expired images")
            
        } catch {
            print("❌ ImageCache: Cleanup failed: \(error)")
        }
    }
    
    // MARK: - Prefetching
    func prefetchImages(from urls: [URL]) {
        for url in urls {
            Task {
                _ = await loadImage(from: url)
            }
        }
    }
    
    // MARK: - Statistics
    func getCacheSize() -> (memory: Int, disk: Int) {
        let memorySize = memoryCache.totalCostLimit
        let diskSize = calculateDiskCacheSize()
        return (memory: memorySize, disk: diskSize)
    }
    
    private func calculateDiskCacheSize() -> Int {
        var totalSize = 0
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in fileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                }
            }
        } catch {
            print("❌ ImageCache: Failed to calculate disk cache size: \(error)")
        }
        
        return totalSize
    }
    
    // MARK: - Utilities
    private func sanitizeKey(_ key: String) -> String {
        return key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }
    
    private func estimateImageCost(_ image: PlatformImage) -> Int {
        #if canImport(UIKit)
        return Int(image.size.width * image.size.height * 4)
        #elseif canImport(AppKit)
        return Int(image.size.width * image.size.height * 4)
        #endif
    }
    
    private func schedulePeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupExpiredImages()
        }
    }
    
    // MARK: - Memory Management
    #if canImport(UIKit)
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
        print("⚠️ ImageCache: Memory warning - cleared memory cache")
    }
    
    @objc private func handleAppBackground() {
        cleanupExpiredImages()
        print("📱 ImageCache: App backgrounded - performing cleanup")
    }
    #endif
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum CacheError: Error {
    case downloadFailed
    case invalidData
    case diskWriteFailed
}

struct CacheStatistics: Equatable {
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var misses: Int = 0
    var insertions: Int = 0
    var cleanupCount: Int = 0
    
    var hitRate: Double {
        let totalRequests = memoryHits + diskHits + misses
        guard totalRequests > 0 else { return 0 }
        return Double(memoryHits + diskHits) / Double(totalRequests)
    }
}

// MARK: - Convenience Extensions

extension ImageCache {
    func preloadImages(from urlStrings: [String]) {
        let urls = urlStrings.compactMap { URL(string: $0) }
        prefetchImages(from: urls)
    }
}
