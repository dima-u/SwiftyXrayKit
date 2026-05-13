//
// XrayBridge.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//
// Bridges NEPacketTunnelFlow ↔ XRay's built-in gVisor tun inbound.
// XRay is configured with a "tun" protocol inbound; its fd is a SOCK_STREAM
// socketpair. No hev or SOCKS5 layer needed.
//
// Data flow:
//   packetFlow.readPackets → [4-byte AF header][IP packet] → socketpair fd[1]
//       → fd[0] → XRay gVisor → outbound proxy → remote
//   remote → outbound proxy → XRay gVisor → fd[0]
//       → fd[1] recv → [4-byte AF header][IP packet] → packetFlow.writePackets

import Foundation
import NetworkExtension
import Darwin

public enum XrayBridgeError: Error {
    case socketPairFailed
    case invalidConfig
}

public final class XrayBridge {

    private weak var packetFlow: NEPacketTunnelFlow?
    private var swiftFd: Int32 = -1
    private var xrayFd: Int32 = -1
    private var isRunning = false

    private let statsLock = NSLock()
    private var _bytesReceived: Int64 = 0  // device ← remote (read thread)
    private var _bytesSent: Int64 = 0      // device → remote (packet flow)

    public init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    deinit {
        if xrayFd >= 0 { Darwin.close(xrayFd) }
        if swiftFd >= 0 { Darwin.close(swiftFd) }
    }

    /// Starts XRay, building the config from `config` JSON.
    ///
    /// The kit injects the TUN inbound and optional sniffing, then calls
    /// `configTransform` (if provided) so you can mutate any part of the
    /// dictionary before it is written to `finalConfigPath` and run.
    ///
    /// - Parameters:
    ///   - config: Intermediate Xray JSON (outbounds, routing, etc. — no inbound needed).
    ///   - dataDir: Directory containing geo data files.
    ///   - finalConfigPath: Where the final JSON is written before running.
    ///   - sniffing: Optional sniffing injected into the TUN inbound.
    ///   - preset: Tuning preset to apply before run. Defaults to `.default`.
    ///   - configTransform: Optional closure receiving the kit-built config dictionary.
    ///                      Return a modified copy to customise anything before writing.
    ///   - traceHandle: Optional log sink for Xray lifecycle messages.
    public func start(
        config: XrayIntermediateConfig,
        dataDir: URL,
        finalConfigPath: URL,
        sniffing: SniffingConfiguration? = nil,
        preset: XrayTuningPreset = .default,
        configTransform: (([String: Any]) -> [String: Any])? = nil,
        traceHandle: ((String) -> Void)? = nil
    ) throws {
        let json: String
        switch config {
        case .json(let s): json = s
        case .url(let link): json = try SwiftyXray.xrayShareLinkToJson(url: link)
        }
        try openSocketPairAndApplyPreset(preset)
        var dict = try buildConfigDict(json: json, sniffing: sniffing)
        if let transform = configTransform { dict = transform(dict) }
        try writeAndRun(dict: dict, dataDir: dataDir, finalConfigPath: finalConfigPath, traceHandle: traceHandle)
    }

    /// Starts XRay with a fully pre-built config file — no patching applied.
    ///
    /// Use this when you want complete control over the Xray JSON.
    /// The kit only creates the socketpair and passes the fd to Xray before running.
    ///
    /// - Parameters:
    ///   - rawConfigPath: Path to your pre-built Xray config JSON.
    ///   - dataDir: Directory containing geo data files.
    ///   - preset: Tuning preset to apply before run. Defaults to `.default`.
    ///   - traceHandle: Optional log sink for Xray lifecycle messages.
    public func startWithRawConfig(
        rawConfigPath: URL,
        dataDir: URL,
        preset: XrayTuningPreset = .default,
        traceHandle: ((String) -> Void)? = nil
    ) throws {
        try openSocketPairAndApplyPreset(preset)
        try SwiftyXray.run(dataDir: dataDir.path, configPath: rawConfigPath.path, traceHandle: traceHandle)
        isRunning = true
        launchReadThread(fd: swiftFd)
        readFromPacketFlow()
    }

    /// Returns the config dictionary that `start(config:…)` would produce,
    /// without writing or running anything. Use to inspect or test the output.
    public func buildConfig(
        config: XrayIntermediateConfig,
        sniffing: SniffingConfiguration? = nil,
        configTransform: (([String: Any]) -> [String: Any])? = nil
    ) throws -> [String: Any] {
        let json: String
        switch config {
        case .json(let s): json = s
        case .url(let link): json = try SwiftyXray.xrayShareLinkToJson(url: link)
        }
        var dict = try buildConfigDict(json: json, sniffing: sniffing)
        if let transform = configTransform { dict = transform(dict) }
        return dict
    }

    /// Stops XRay and closes the socketpair.
    public func stop() {
        isRunning = false
        let x = xrayFd, s = swiftFd
        xrayFd = -1
        swiftFd = -1
        if x >= 0 { Darwin.close(x) }
        if s >= 0 { Darwin.close(s) }
        try? SwiftyXray.stop()
    }

    /// Returns bytes transferred since last call and resets counters.
    public func getAndClearStats() -> BytesTransferred {
        statsLock.lock()
        let r = _bytesReceived
        let s = _bytesSent
        _bytesReceived = 0
        _bytesSent = 0
        statsLock.unlock()
        return BytesTransferred(received: max(0, r), sent: max(0, s))
    }

    // MARK: - Helpers

    private func openSocketPairAndApplyPreset(_ preset: XrayTuningPreset) throws {
        var fds: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0 else {
            throw XrayBridgeError.socketPairFailed
        }
        xrayFd = fds[0]
        swiftFd = fds[1]
        SwiftyXray.setTunFd(xrayFd)
        preset.apply()
    }

    private func buildConfigDict(json: String, sniffing: SniffingConfiguration?) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              var config = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XrayBridgeError.invalidConfig
        }
        var inbound: [String: Any] = [
            "protocol": "tun",
            "settings": ["name": "utun", "MTU": 1360],
            "tag": "in_proxy"
        ]
        if let sniffing {
            inbound["sniffing"] = [
                "destOverride": sniffing.destOverride,
                "enabled": sniffing.enabled,
                "routeOnly": sniffing.routeOnly,
                "metadataOnly": sniffing.metadataOnly,
                "domainsExcluded": sniffing.domainsExcluded
            ]
        }
        config["inbounds"] = [inbound]
        return config
    }

    private func writeAndRun(
        dict: [String: Any],
        dataDir: URL,
        finalConfigPath: URL,
        traceHandle: ((String) -> Void)?
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        let json = String(decoding: data, as: UTF8.self)
        traceHandle?("###XrayBridge final config: \(json)")
        try json.write(to: finalConfigPath, atomically: true, encoding: .utf8)
        try SwiftyXray.run(dataDir: dataDir.path, configPath: finalConfigPath.path, traceHandle: traceHandle)
        isRunning = true
        launchReadThread(fd: swiftFd)
        readFromPacketFlow()
    }

    // MARK: - Threads

    // Reads packets from XRay (via fd[1]) and forwards them to the packet flow.
    // SOCK_STREAM format: [4-byte big-endian AF][raw IP packet], back-to-back in the stream.
    // Parses IP header length to find each packet boundary.
    // Exits when recv returns 0 or an error (fd closed by stop()).
    private func launchReadThread(fd: Int32) {
        guard let flow = packetFlow else { return }
        Thread.detachNewThread { [weak self] in
            let maxPacket = 65536
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: maxPacket)
            defer { buf.deallocate() }

            var keepRunning = true
            while keepRunning {
                autoreleasepool {
                    // 1. Read 4-byte AF type header
                    guard Darwin.recv(fd, buf, 4, Int32(MSG_WAITALL)) == 4 else {
                        keepRunning = false
                        return
                    }
                    let afRaw = buf.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
                    let af = CFSwapInt32BigToHost(afRaw)
                    let ipBuf = buf

                    let packet: Data
                    if af == UInt32(AF_INET) {
                        // IPv4: read minimum 20-byte header to get IHL and total length
                        guard Darwin.recv(fd, ipBuf, 20, Int32(MSG_WAITALL)) == 20 else {
                            keepRunning = false
                            return
                        }
                        let total = Int(CFSwapInt16BigToHost(
                            ipBuf.withMemoryRebound(to: UInt16.self, capacity: 10) { $0[1] }
                        ))
                        let remaining = max(0, total - 20)
                        if remaining > 0 {
                            guard Darwin.recv(fd, ipBuf + 20, remaining, Int32(MSG_WAITALL)) == remaining else {
                                keepRunning = false
                                return
                            }
                        }
                        packet = Data(bytes: ipBuf, count: total)
                    } else {
                        // IPv6: fixed 40-byte header, payload length at bytes 4-5
                        guard Darwin.recv(fd, ipBuf, 40, Int32(MSG_WAITALL)) == 40 else {
                            keepRunning = false
                            return
                        }
                        let payloadLen = Int(CFSwapInt16BigToHost(
                            ipBuf.withMemoryRebound(to: UInt16.self, capacity: 20) { $0[2] }
                        ))
                        if payloadLen > 0 {
                            guard Darwin.recv(fd, ipBuf + 40, payloadLen, Int32(MSG_WAITALL)) == payloadLen else {
                                keepRunning = false
                                return
                            }
                        }
                        packet = Data(bytes: ipBuf, count: 40 + payloadLen)
                    }

                    if let self {
                        self.statsLock.lock()
                        self._bytesReceived += Int64(packet.count)
                        self.statsLock.unlock()
                    }
                    flow.writePackets([packet], withProtocols: [NSNumber(value: af)])
                }
            }
        }
    }

    // Reads packets from the system via packetFlow and forwards them to XRay (fd[1]).
    // Format written to fd: [4-byte big-endian AF][raw IP packet] as a single write.
    private func readFromPacketFlow() {
        guard isRunning, let packetFlow else { return }
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, self.isRunning, self.swiftFd >= 0 else { return }
            let fd = self.swiftFd
            for (packet, proto) in zip(packets, protocols) {
                var afBig = CFSwapInt32HostToBig(proto.uint32Value)
                packet.withUnsafeBytes { packetBuf in
                    withUnsafeBytes(of: &afBig) { headerBuf in
                        guard let packetBase = packetBuf.baseAddress,
                              let headerBase = headerBuf.baseAddress else { return }
                        var iov = [
                            iovec(iov_base: UnsafeMutableRawPointer(mutating: headerBase), iov_len: 4),
                            iovec(iov_base: UnsafeMutableRawPointer(mutating: packetBase), iov_len: packet.count)
                        ]
                        _ = Darwin.writev(fd, &iov, 2)
                    }
                }
                self.statsLock.lock()
                self._bytesSent += Int64(packet.count)
                self.statsLock.unlock()
            }
            self.readFromPacketFlow()
        }
    }
}
