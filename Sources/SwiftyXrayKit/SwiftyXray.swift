//
// SwiftyXray.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation
import Swift
import LibXray

/// Main wrapper class for Xray functionality
public class SwiftyXray {
  /// Allocates the specified number of free ports
  /// - Parameter count: Number of ports to allocate
  /// - Returns: Array of allocated port numbers
  /// - Throws: SwiftyXRayError if port allocation fails
  public static func getFreePorts(_ count: Int) throws -> [Int] {
    let base64JsonResponse = LibXrayGetFreePorts(count)
    let portsResponse = try XrayPortsResponse(base64String: base64JsonResponse)
    if let ports = portsResponse.data?.ports {
      return ports
    } else {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
  }

  /// Sets the TUN file descriptor used by the tun inbound.
  /// Must be called before run().
  public static func setTunFd(_ fd: Int32) {
    LibXraySetTunFd(fd)
  }

  /// Sets the Go heap memory ceiling in megabytes.
  /// Must be called before run().
  public static func setMemoryLimitMB(_ mb: Int64) {
    LibXraySetMemoryLimitMB(mb)
  }

  /// Sets the max TCP RX/TX buffer size per connection in kilobytes.
  /// Must be called before run().
  public static func setTCPBufMaxKB(_ kb: Int32) {
    LibXraySetTCPBufMaxKB(kb)
  }

  /// Sets the max concurrent TCP connections.
  /// Must be called before run().
  public static func setTCPMaxInFlight(_ n: Int32) {
    LibXraySetTCPMaxInFlight(n)
  }

  /// Sets the max concurrent UDP sessions.
  /// Must be called before run().
  public static func setMaxUDPConns(_ n: Int32) {
    LibXraySetMaxUDPConns(n)
  }

  /// Runs Xray with the specified configuration.
  /// Run this method only if you have your own socks5 proxy setup or any other inbound.
  ///
  /// - Parameters:
  ///   - dataDir: Directory for Xray data files
  ///   - configPath: Path to the Xray configuration file
  /// - Throws: SwiftyXRayError if Xray fails to start
  public static func run(dataDir: String, configPath: String, traceHandle: ((String) -> Void)? = nil) throws {
    let jsonRequest = try JSONEncoder().encode(XRayRunRequest(datDir: dataDir, configPath: configPath))

    traceHandle?("###SwiftyXray request: \(jsonRequest)")
    let base64JsonResponse = LibXrayRunXray(jsonRequest.base64EncodedString())

    traceHandle?("###SwiftyXray file path: \(configPath)")

    let exists = FileManager.default.fileExists(atPath: configPath)
    traceHandle?("###SwiftyXray file exists: \(exists)")

    let runResponse = try XrayBoolResponse(base64String: base64JsonResponse)
    if !runResponse.success {
      traceHandle?("###SwiftyXray failed to launch!")
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    } else {
      traceHandle?("###SwiftyXray started succesful!")
    }
  }

  /// Stops the running Xray instance
  /// - Throws: SwiftyXRayError if stopping fails
  public static func stop() throws {
    let base64JsonResponse = LibXrayStopXray()
    let runResponse = try XrayBoolResponse(base64String: base64JsonResponse)
    if !runResponse.success {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
  }
  
  /// Gets the current Xray version
  /// - Returns: Version string
  /// - Throws: SwiftyXRayError if version retrieval fails
  public static func xrayVersion() throws -> String {
    let base64JsonResponse = LibXrayXrayVersion()
    let runResponse = try XrayVersionResponse(base64String: base64JsonResponse)
    guard let version = runResponse.data else {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
    
    if !runResponse.success {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
    
    return version
  }
  
  /// Converts an Xray share link URL to JSON configuration
  /// - Parameter url: Share link URL to convert
  /// - Returns: JSON configuration string
  /// - Throws: SwiftyXRayError if conversion fails
  public static func xrayShareLinkToJson(url: String) throws -> String {
    let base64JsonResponse = LibXrayConvertShareLinksToXrayJson(Data(url.utf8).base64EncodedString())
    
    guard let jsonResponse = base64JsonResponse.fromBase64(),
          let respData = jsonResponse.data(using: .utf8) else {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
    
    guard let json = try JSONSerialization.jsonObject(with: respData, options: []) as? [String: Any] else {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
    
    guard (json["success"] as? Bool) == true else {
      throw SwiftyXRayError.invalidResponse(json.description)
    }
    
    guard let nestedObj = json["data"] as? Dictionary<String, Any> else {
      throw SwiftyXRayError.invalidResponse(json.description)
    }

    guard let dt = try? JSONSerialization.data(withJSONObject: nestedObj),
          let str = String(data: dt, encoding: .utf8) else {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
    }
    
    return str
  }
}
