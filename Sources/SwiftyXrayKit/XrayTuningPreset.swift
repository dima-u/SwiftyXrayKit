//
// XrayTuningPreset.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// A set of Xray tuning parameters. Call apply() before SwiftyXray.run().
public struct XrayTuningPreset: Sendable {
    /// Go heap ceiling in MB.
    public var memoryLimitMB: Int
    /// Max TCP RX/TX buffer per connection in KB.
    public var tcpBufMaxKB: Int
    /// Max concurrent TCP connections (gVisor in-flight limit).
    public var tcpMaxInFlight: Int
    /// Max concurrent UDP sessions.
    public var udpMaxConns: Int
    /// Inbound idle timeout in seconds (for use in config generation).
    public var idleTimeoutSec: Int

    public init(
        memoryLimitMB: Int,
        tcpBufMaxKB: Int,
        tcpMaxInFlight: Int,
        udpMaxConns: Int,
        idleTimeoutSec: Int
    ) {
        self.memoryLimitMB = memoryLimitMB
        self.tcpBufMaxKB = tcpBufMaxKB
        self.tcpMaxInFlight = tcpMaxInFlight
        self.udpMaxConns = udpMaxConns
        self.idleTimeoutSec = idleTimeoutSec
    }

    /// Applies all tuning parameters. Call before SwiftyXray.run().
    public func apply() {
        SwiftyXray.setMemoryLimitMB(Int64(memoryLimitMB))
        SwiftyXray.setTCPBufMaxKB(Int32(tcpBufMaxKB))
        SwiftyXray.setTCPMaxInFlight(Int32(tcpMaxInFlight))
        SwiftyXray.setMaxUDPConns(Int32(udpMaxConns))
    }
}

public extension XrayTuningPreset {
    /// Optimised for iOS Network Extension memory constraints.
    static let mobile = XrayTuningPreset(
        memoryLimitMB: 30,
        tcpBufMaxKB: 1024,
        tcpMaxInFlight: 512,
        udpMaxConns: 256,
        idleTimeoutSec: 120
    )

    /// Optimised for macOS / desktop (no memory cap, full connection limits).
    static let desktop = XrayTuningPreset(
        memoryLimitMB: 50,
        tcpBufMaxKB: 4096,
        tcpMaxInFlight: 8192,
        udpMaxConns: 4096,
        idleTimeoutSec: 300
    )

    /// Platform-adaptive: .mobile on iOS/tvOS, .desktop on macOS.
    static var `default`: XrayTuningPreset {
        #if os(macOS)
        return .desktop
        #else
        return .mobile
        #endif
    }
}
