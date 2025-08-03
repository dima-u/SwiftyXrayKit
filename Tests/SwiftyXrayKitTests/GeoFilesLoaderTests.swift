//
//
// GeoFilesLoaderTests.swift
// SwiftyXrayKitTests
//
// Copyright © 2025 canvas.io. All rights reserved.
//

import XCTest
import Foundation
@testable import SwiftyXrayKit

@available(macOS 13.0, iOS 15.0, *)
final class GeoFilesLoaderTests: XCTestCase {
    
    var tempDirectory: URL!
    var geoFilesLoader: GeoFilesLoader!
    var progress: Double = 0
    
    override func setUp() {
        super.setUp()
        
        // Create a temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoFilesLoaderTests")
            .appendingPathComponent(UUID().uuidString)
        
        geoFilesLoader = GeoFilesLoader()
        
        // Create the test directory
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDown() {
        // Clean up the temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        tempDirectory = nil
        geoFilesLoader = nil
        
        super.tearDown()
    }
    
    // MARK: - Valid URL Tests
    
    func testLoadGeoFilesWithValidURLs() async throws {
        // Use actual GitHub URLs that should work
        let validGeoIPURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat")!
        let validGeoSiteURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat")!
        
        var progressUpdates: [Double] = []
        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 1 // At least one progress update
        
        try await geoFilesLoader.loadGeoFiles(
            into: tempDirectory,
            geoSiteURL: validGeoSiteURL,
            geoIPURL: validGeoIPURL,
            progressCallback: { progress in
                progressUpdates.append(progress)
                if progress >= 1.0 {
                    progressExpectation.fulfill()
                }
            }
        )
        
        await fulfillment(of: [progressExpectation], timeout: 60.0)
        
        // Verify files were downloaded
        let geoIPFile = tempDirectory.appendingPathComponent("geoip.dat")
        let geoSiteFile = tempDirectory.appendingPathComponent("geosite.dat")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoIPFile.path), "GeoIP file should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoSiteFile.path), "GeoSite file should exist")
        
        // Verify files have content
        let geoIPData = try Data(contentsOf: geoIPFile)
        let geoSiteData = try Data(contentsOf: geoSiteFile)
        
        XCTAssertGreaterThan(geoIPData.count, 0, "GeoIP file should not be empty")
        XCTAssertGreaterThan(geoSiteData.count, 0, "GeoSite file should not be empty")
        
        // Verify progress updates
        XCTAssertGreaterThan(progressUpdates.count, 0, "Should have received progress updates")
        XCTAssertEqual(progressUpdates.last, 1.0, "Final progress should be 1.0")
        
        // Verify progress is monotonically increasing or staying the same
        for i in 1..<progressUpdates.count {
            XCTAssertGreaterThanOrEqual(progressUpdates[i], progressUpdates[i-1], "Progress should not decrease")
        }
    }
    
    func testLoadGeoFilesWithDefaultURLs() async throws {
        progress = 0
        let progressExpectation = expectation(description: "Progress updates received")
        
        try await geoFilesLoader.loadGeoFiles(
            into: tempDirectory,
            geoSiteURL: nil, // Use defaults
            geoIPURL: nil,   // Use defaults
            progressCallback: { [weak self] progress in

              debugPrint("progress called: \(progress)")
              
              self?.progress = progress
                if progress >= 1.0 {
                    progressExpectation.fulfill()
                }
            }
        )
        
        await fulfillment(of: [progressExpectation], timeout: 60.0)
        
        // Verify files were downloaded
        let geoIPFile = tempDirectory.appendingPathComponent("geoip.dat")
        let geoSiteFile = tempDirectory.appendingPathComponent("geosite.dat")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoIPFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoSiteFile.path))
    
      XCTAssertEqual(self.progress, 1.0, "Final progress should be 1.0")
    }
    
    // MARK: - Invalid URL Tests
    
    func testLoadGeoFilesWithInvalidGeoIPURL() async {
        let invalidGeoIPURL = URL(string: "https://invalid-domain-that-does-not-exist-12345.com/geoip.dat")!
        let validGeoSiteURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat")!
        
        do {
            try await geoFilesLoader.loadGeoFiles(
                into: tempDirectory,
                geoSiteURL: validGeoSiteURL,
                geoIPURL: invalidGeoIPURL
            )
            XCTFail("Should have thrown an error for invalid GeoIP URL")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is URLError || error is NSError, "Should throw a URL-related error")
        }
    }
    
    func testLoadGeoFilesWithInvalidGeoSiteURL() async {
        let validGeoIPURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat")!
        let invalidGeoSiteURL = URL(string: "https://invalid-domain-that-does-not-exist-12345.com/geosite.dat")!
        
        do {
            try await geoFilesLoader.loadGeoFiles(
                into: tempDirectory,
                geoSiteURL: invalidGeoSiteURL,
                geoIPURL: validGeoIPURL
            )
            XCTFail("Should have thrown an error for invalid GeoSite URL")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is URLError || error is NSError, "Should throw a URL-related error")
        }
    }
    
    func testLoadGeoFilesWithBothInvalidURLs() async {
        let invalidGeoIPURL = URL(string: "https://invalid-domain-1.com/geoip.dat")!
        let invalidGeoSiteURL = URL(string: "https://invalid-domain-2.com/geosite.dat")!
        
        do {
            try await geoFilesLoader.loadGeoFiles(
                into: tempDirectory,
                geoSiteURL: invalidGeoSiteURL,
                geoIPURL: invalidGeoIPURL
            )
            XCTFail("Should have thrown an error for both invalid URLs")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is URLError || error is NSError, "Should throw a URL-related error")
        }
    }
    
    func testLoadGeoFilesWithNonExistentPath() async {
        let validGeoIPURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat")!
        let validGeoSiteURL = URL(string: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat")!
        let nonExistentPathURL = validGeoIPURL.appendingPathComponent("nonexistent.dat")
        
        do {
            try await geoFilesLoader.loadGeoFiles(
                into: tempDirectory,
                geoSiteURL: validGeoSiteURL,
                geoIPURL: nonExistentPathURL
            )
            XCTFail("Should have thrown an error for non-existent file path")
        } catch {
            // Expected to fail with 404 or similar
            if let urlError = error as? URLError {
                // Could be various URL errors depending on server response
                XCTAssertTrue([.badServerResponse, .cannotFindHost, .resourceUnavailable].contains(urlError.code))
            } else {
                XCTFail("Expected URLError, got \(type(of: error))")
            }
        }
    }
    
    // MARK: - Progress Callback Tests
    
    func testProgressCallbackIsOptional() async throws {
        // Test that progress callback is optional and doesn't cause issues when nil
        let validGeoIPURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/README.md")! // Smaller file for faster test
        let validGeoSiteURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/LICENSE.txt")! // Smaller file for faster test
        
        // This should not crash or fail
        try await geoFilesLoader.loadGeoFiles(
            into: tempDirectory,
            geoSiteURL: validGeoSiteURL,
            geoIPURL: validGeoIPURL,
            progressCallback: nil
        )
        
        // Verify files were still downloaded
        let geoIPFile = tempDirectory.appendingPathComponent("geoip.dat")
        let geoSiteFile = tempDirectory.appendingPathComponent("geosite.dat")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoIPFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoSiteFile.path))
    }
    
    func testProgressCallbackReceivesValidRange() async throws {
        let validGeoIPURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/README.md")!
        let validGeoSiteURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/LICENSE.txt")!
        
        var progressUpdates: [Double] = []
        let progressExpectation = expectation(description: "Progress completion")
        
        try await geoFilesLoader.loadGeoFiles(
            into: tempDirectory,
            geoSiteURL: validGeoSiteURL,
            geoIPURL: validGeoIPURL,
            progressCallback: { progress in
                progressUpdates.append(progress)
                
                // Verify progress is in valid range
                XCTAssertGreaterThanOrEqual(progress, 0.0, "Progress should be >= 0.0")
                XCTAssertLessThanOrEqual(progress, 1.0, "Progress should be <= 1.0")
                
                if progress >= 1.0 {
                    progressExpectation.fulfill()
                }
            }
        )
        
        await fulfillment(of: [progressExpectation], timeout: 30.0)
        
        XCTAssertGreaterThan(progressUpdates.count, 0, "Should have received progress updates")
        XCTAssertEqual(progressUpdates.last, 1.0, "Final progress should be 1.0")
    }
    
    // MARK: - File System Tests
    
    func testDirectoryCreation() async throws {
        let nonExistentDirectory = tempDirectory.appendingPathComponent("nested/deep/directory")
        
        // Verify directory doesn't exist initially
        XCTAssertFalse(FileManager.default.fileExists(atPath: nonExistentDirectory.path))
        
        let validGeoIPURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/README.md")!
        let validGeoSiteURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/LICENSE.txt")!
        
        try await geoFilesLoader.loadGeoFiles(
            into: nonExistentDirectory,
            geoSiteURL: validGeoSiteURL,
            geoIPURL: validGeoIPURL
        )
        
        // Verify directory was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: nonExistentDirectory.path))
        
        // Verify files were downloaded
        let geoIPFile = nonExistentDirectory.appendingPathComponent("geoip.dat")
        let geoSiteFile = nonExistentDirectory.appendingPathComponent("geosite.dat")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoIPFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoSiteFile.path))
    }
    
    func testFileOverwrite() async throws {
        // Create initial files
        let geoIPFile = tempDirectory.appendingPathComponent("geoip.dat")
        let geoSiteFile = tempDirectory.appendingPathComponent("geosite.dat")
        
        let initialData = "initial content".data(using: .utf8)!
        try initialData.write(to: geoIPFile)
        try initialData.write(to: geoSiteFile)
        
        // Verify initial files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoIPFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: geoSiteFile.path))
        
        let validGeoIPURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/README.md")!
        let validGeoSiteURL = URL(string: "https://raw.githubusercontent.com/apple/swift/main/LICENSE.txt")!
        
        try await geoFilesLoader.loadGeoFiles(
            into: tempDirectory,
            geoSiteURL: validGeoSiteURL,
            geoIPURL: validGeoIPURL
        )
        
        // Verify files were overwritten with new content
        let newGeoIPData = try Data(contentsOf: geoIPFile)
        let newGeoSiteData = try Data(contentsOf: geoSiteFile)
        
        XCTAssertNotEqual(newGeoIPData, initialData, "GeoIP file should be overwritten")
        XCTAssertNotEqual(newGeoSiteData, initialData, "GeoSite file should be overwritten")
        XCTAssertGreaterThan(newGeoIPData.count, initialData.count, "New GeoIP file should be larger")
        XCTAssertGreaterThan(newGeoSiteData.count, initialData.count, "New GeoSite file should be larger")
    }
}
