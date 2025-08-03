//
// BytesTransferred.swift
// XrayWrapper
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Tracks the amount of data transferred through the tunnel
public struct BytesTransferred {
  /// Number of bytes received from the tunnel
  public var received: UInt32
  
  /// Number of bytes sent through the tunnel
  public var sent: UInt32
  
  /// Creates a new BytesTransferred instance with zero values
  public init() {
    self.received = 0
    self.sent = 0
  }
  
  /// Creates a new BytesTransferred instance with specific values
  /// - Parameters:
  ///   - received: Initial received bytes count
  ///   - sent: Initial sent bytes count
  public init(received: UInt32, sent: UInt32) {
    self.received = received
    self.sent = sent
  }
  
  /// Returns a new BytesTransferred instance with incremented received bytes
  /// - Parameter value: Number of bytes to add to received count
  /// - Returns: New BytesTransferred instance with updated received count
  public func incrementReceived(by value: UInt32) -> BytesTransferred {
    var mutableSelf = self
    mutableSelf.received += value
    return mutableSelf
  }
  
  /// Returns a new BytesTransferred instance with incremented sent bytes
  /// - Parameter value: Number of bytes to add to sent count
  /// - Returns: New BytesTransferred instance with updated sent count
  public func incrementSent(by value: UInt32) -> BytesTransferred {
    var mutableSelf = self
    mutableSelf.sent += value
    return mutableSelf
  }
}
