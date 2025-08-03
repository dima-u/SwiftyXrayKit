//
// SwiftyXray.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation
import Swift
import SwiftyXrayCore

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
  
  /// Runs Xray with the specified configuration.
  /// Run this method only if you have your own socks5 proxy setup or any other inbound.
  ///
  /// - Parameters:
  ///   - dataDir: Directory for Xray data files
  ///   - configPath: Path to the Xray configuration file
  /// - Throws: SwiftyXRayError if Xray fails to start
  public static func run(dataDir: String, configPath: String) throws {
    let jsonRequest = try JSONEncoder().encode(XRayRunRequest(datDir: dataDir, configPath: configPath))
    let base64JsonResponse = LibXrayRunXray(jsonRequest.base64EncodedString())
    
    let runResponse = try XrayBoolResponse(base64String: base64JsonResponse)
    if !runResponse.success {
      throw SwiftyXRayError.invalidResponse(base64JsonResponse)
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
