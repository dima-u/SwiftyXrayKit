//
// XrayErrors.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Errors that can occur during Xray operations
public enum SwiftyXRayError: Error, LocalizedError {
  case invalidResponse(String)
  case invalidConfig
  case portAllocationError
  case tunnelSetupError(String)

  public var errorDescription: String? {
    switch self {
    case .invalidResponse(let response):
      return "Invalid response from Xray: \(response)"
    case .invalidConfig:
      return "Invalid Xray configuration"
    case .portAllocationError:
      return "Failed to allocate a free port"
    case .tunnelSetupError(let message):
      return "Tunnel setup error: \(message)"
    }
  }
}
