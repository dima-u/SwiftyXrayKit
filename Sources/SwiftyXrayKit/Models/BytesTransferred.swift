//
// BytesTransferred.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Tracks the amount of data transferred through the tunnel
public struct BytesTransferred: Sendable {
  public var received: Int64
  public var sent: Int64

  public init() {
    self.received = 0
    self.sent = 0
  }

  public init(received: Int64, sent: Int64) {
    self.received = received
    self.sent = sent
  }
}
