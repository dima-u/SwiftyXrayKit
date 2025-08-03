//
//
// GeoFilesLoader.swift
// SwiftyXrayKit
//
// Copyright © 2025 canvas.io. All rights reserved.
//
import Foundation

/// A utility class for downloading and managing Xray geo files (geoip.dat and geosite.dat).
///
/// This class handles the concurrent download of geographical IP and site database files
/// that are required for Xray proxy functionality. It provides progress tracking and
/// uses lightweight files to ensure fast VPN setup.
public class GeoFilesLoader {
  /// important! Use lightweight files in order to make vpn setup fast enough
  public var geoIPUrl = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat")!
  public var geoSiteUrl = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat")!
  
  /// Downloads geoip.dat and geosite.dat files concurrently to the specified directory.
  ///
  /// This method creates the target directory if it doesn't exist and downloads both geo files
  /// in parallel for optimal performance. Progress is tracked across both downloads and reported
  /// through the optional callback.
  ///
  /// - Parameters:
  ///   - directory: The destination directory where the geo files will be saved
  ///   - geoSiteURL: Optional custom URL for the geosite.dat file. If nil, uses the default URL
  ///   - geoIPURL: Optional custom URL for the geoip.dat file. If nil, uses the default URL
  ///   - progressCallback: Optional closure that receives download progress (0.0 to 1.0)
  ///
  /// - Throws:
  ///   - `URLError` if network requests fail
  ///   - `CocoaError` if file system operations fail
  ///   - Any other errors from the underlying download tasks
  ///
  /// - Note: Files are downloaded to `geoip.dat` and `geosite.dat` in the specified directory.
  ///         Any existing files with these names will be replaced.
  public func loadGeoFiles(
    into directory: URL,
    geoSiteURL: URL?,
    geoIPURL: URL?,
    progressCallback: ((Double) -> Void)? = nil
  ) async throws {
    // Use provided URLs or fall back to defaults
    let finalGeoIPURL = geoIPURL ?? self.geoIPUrl
    let finalGeoSiteURL = geoSiteURL ?? self.geoSiteUrl
    
    // Create directory if it doesn't exist
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    
    // Define destination file paths
    let geoIPDestination = directory.appendingPathComponent("geoip.dat")
    let geoSiteDestination = directory.appendingPathComponent("geosite.dat")
    
    // Track progress for both downloads (each represents 50% of total progress)
    var geoIPProgress: Double = 0.0
    var geoSiteProgress: Double = 0.0
    
    let updateProgress = {
      let totalProgress = (geoIPProgress + geoSiteProgress) / 2.0
      progressCallback?(totalProgress)
    }
    
    // Download both files concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
      // Download GeoIP file
      group.addTask {
        try await self.downloadFile(
          from: finalGeoIPURL,
          to: geoIPDestination,
          progressCallback: { progress in
            geoIPProgress = progress
            updateProgress()
          }
        )
      }
      
      // Download GeoSite file
      group.addTask {
        try await self.downloadFile(
          from: finalGeoSiteURL,
          to: geoSiteDestination,
          progressCallback: { progress in
            geoSiteProgress = progress
            updateProgress()
          }
        )
      }
      
      // Wait for both downloads to complete
      try await group.waitForAll()
    }
    
  }
  
  private func downloadFile(
    from url: URL,
    to destination: URL,
    progressCallback: @escaping (Double) -> Void
  ) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      // Remove existing file if it exists
      try? FileManager.default.removeItem(at: destination)
      
      let urlRequest = URLRequest(url: url)
      var progressObserver: NSKeyValueObservation?
      
      let downloadTask = URLSession.shared.downloadTask(with: urlRequest) { tempURL, response, error in
        // Clean up observer
        progressObserver?.invalidate()
        progressObserver = nil
        
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
          continuation.resume(throwing: URLError(.badServerResponse))
          return
        }
        
        guard let tempURL = tempURL else {
          continuation.resume(throwing: URLError(.cannotCreateFile))
          return
        }
        
        do {
          // Move the downloaded file to the final destination
          try FileManager.default.moveItem(at: tempURL, to: destination)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
      
      // Observe progress
      progressObserver = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
        DispatchQueue.main.async {
          progressCallback(progress.fractionCompleted)
        }
      }
      
      // Start the download
      downloadTask.resume()
    }
  }
}
