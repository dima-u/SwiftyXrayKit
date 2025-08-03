//
// XrayResponses.swift
// XrayWrapper
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Generic response wrapper for Xray library responses
struct XrayResponse<T: Decodable>: Decodable {
  let success: Bool
  let data: T?
  
  init(base64String: String) throws {
    let plainStr = base64String.fromBase64() ?? ""
    let selfCopy = try JSONDecoder().decode(XrayResponse<T>.self, from: plainStr.data(using: .utf8) ?? Data())
    success = selfCopy.success
    data = selfCopy.data
  }
}

/// Response body for port allocation requests
struct XrayPortsResponseBody: Codable {
  let ports: [Int]
}

/// Request structure for running Xray
struct XRayRunRequest: Codable {
  let datDir: String
  let configPath: String
  
  enum CodingKeys: String, CodingKey {
    case datDir = "datDir"
    case configPath = "configPath"
  }
}

// Type aliases for specific response types
typealias XrayPortsResponse = XrayResponse<XrayPortsResponseBody>
typealias XrayVersionResponse = XrayResponse<String>
typealias XrayBoolResponse = XrayResponse<Bool>
