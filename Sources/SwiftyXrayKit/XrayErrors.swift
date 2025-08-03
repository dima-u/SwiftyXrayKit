//
// XrayErrors.swift
// XrayWrapper
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Errors that can occur during Xray operations
public enum SwiftyXRayError: Error, LocalizedError {
  /// Invalid response received from Xray library
  case invalidResponse(String)
  
  /// Invalid configuration provided
  case invalidConfig
  
  /// Failed to allocate a free port for SOCKS5
  case portAllocationError
  
  /// Setup error with detailed message
  case tunnelSetupError(String)
  
  public var errorDescription: String? {
    switch self {
    case .invalidResponse(let response):
      return "Invalid response from Xray: \(response)"
    case .invalidConfig:
      return "Invalid Xray configuration provided"
    case .portAllocationError:
      return "Failed to allocate a free port for SOCKS5 tunnel"
    case .tunnelSetupError(let message):
      return "SOCKS5 setup error: \(message)"
    }
  }
}
