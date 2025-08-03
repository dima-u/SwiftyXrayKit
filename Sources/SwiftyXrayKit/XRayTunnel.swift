//
// XRayTunnel.swift
// SwiftyXrayKit
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation
import NetworkExtension
import SwiftyXrayCore

/// Main Xray tunnel actor that manages the VPN tunnel connection
public actor XRayTunnel: NSObject {
  
  public var defaultNameServers: [String] = ["8.8.8.8", "1.1.1.1"]
  
  /// Current bytes transfer statistics
  public var bytesTransferred: BytesTransferred = .init()
  
  /// Current state
  var isRunning = false
  
  /// Weak reference to the packet flow for reading/writing packets
  weak var packetFlow: NEPacketTunnelFlow?
  
  // Private properties for tunnel management
  private var client: OutlineClient?
  private var shadowTunnel: Tun2socksTunnelProtocol?
  private var socks5Port: Int = 0
  
  /// Initializes the tunnel with a packet flow
  /// - Parameter packetFlow: The NEPacketTunnelFlow for packet processing
  public init(packetFlow: NEPacketTunnelFlow) {
    self.packetFlow = packetFlow
  }
  
  /// Starts the Xray tunnel with the provided configuration
  /// - Parameters:
  ///   - dataDir: Directory for Xray data files, such as geoIP.dat
  ///   - config: Intermediate configuration (JSON or URL)
  ///   - finalConfigPath: Path where the final JSON config will be written
  ///   - inboundSniffing: Optional sniffing configuration
  /// - Throws: SwiftyXRayError on failure
  public func run(
    dataDir: URL,
    config: XrayIntermediateConfig,
    finalConfigPath: URL,
    inboundSniffing: SniffingConfiguration? = nil
  ) throws {
    guard isRunning == false else { return }
    
    try setupSocks5()
    
    let jsonIntermediate: String
    switch config {
    case let .json(config):
      jsonIntermediate = config
    case let .url(config):
      jsonIntermediate = try SwiftyXray.xrayShareLinkToJson(url: config)
    }
    
    guard let jsonData = jsonIntermediate.data(using: .utf8),
          var jsonConfig = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
      throw SwiftyXRayError.invalidConfig
    }
    
    jsonConfig = patchConfig(config: jsonConfig, sniffing: inboundSniffing)
    
    try JSONSerialization.data(withJSONObject: jsonConfig).write(to: finalConfigPath)
    
    try SwiftyXray.run(dataDir: dataDir.path, configPath: finalConfigPath.path)
    
    isRunning = true
    read()
  }
  
  /// Stops the tunnel and cleans up resources
  public func stop() {
    try? SwiftyXray.stop()
    shadowTunnel?.disconnect()
    shadowTunnel = nil
    client = nil
    isRunning = false
  }
  
  // MARK: - Private Methods
  
  /// Patches the Xray configuration with inbound settings
  private func patchConfig(config: [String: Any], sniffing: SniffingConfiguration?) -> [String: Any] {
    var config = config
    var inbound: [String: Any] = [
      "listen": "127.0.0.1",
      "port": socks5Port,
      "protocol": "socks",
      "settings": ["udp": true]
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
    
    if config["dns"] == nil {
      config["dns"] = ["servers": defaultNameServers, "queryStrategy": "UseIPv4"]
    }
    
    config["inbounds"] = [inbound]
    return config
  }
  
  /// Sets up the SOCKS5 proxy tunnel
  private func setupSocks5() throws {
    guard let port = try SwiftyXray.getFreePorts(1).first else {
      throw SwiftyXRayError.portAllocationError
    }
    
    let client = OutlineNewClient("endpoint: 127.0.0.1:\(port)")
    
    if let err = client?.error {
      throw SwiftyXRayError.tunnelSetupError(err.description)
    }
    guard let client = client?.client else {
      throw SwiftyXRayError.tunnelSetupError("no client returned")
    }
    self.client = client
    
    let shadowTunnelResult = Tun2socksConnectOutlineTunnel(self, client, true)
    
    if let err = shadowTunnelResult?.error {
      throw SwiftyXRayError.tunnelSetupError("failed to bind XRay: \(err.description)")
    }
    
    if let tunnel = shadowTunnelResult?.tunnel {
      shadowTunnel = tunnel
    }
    self.socks5Port = port
  }
  
  /// Main packet reading loop
  func read() {
    guard isRunning else { return }
    Task {
      packetFlow?.readPackets(completionHandler: { [weak self] packetsArray, protosArray in
        guard let self else { return }
        Task {
          await self.read(packetsArray: packetsArray)
        }
      })
    }
  }

  private func read(packetsArray: [Data]) {
    guard let shadowTunnel = self.shadowTunnel else { return }
    var totalBytesWritten: UInt32 = 0
    
    packetsArray.forEach { packet in
      var bytesWritten: Int = 0
      do {
        try shadowTunnel.write(packet, ret0_: &bytesWritten)
        totalBytesWritten += UInt32(bytesWritten)
      } catch { }
    }

    bytesTransferred = bytesTransferred.incrementSent(by: totalBytesWritten)
    read()
  }
}

extension XRayTunnel: Tun2socksTunWriterProtocol {
  public nonisolated func close() throws {
    Task {
      await stop()
    }
  }

  public nonisolated func write(_ p0: Data?, n: UnsafeMutablePointer<Int>?) throws {
    guard let data = p0, data.count > 0 else { return }
    Task {
      await self.write(data: data)
    }
  }
  
  private func write(data: Data) {
    let version = IPVersion.scan(data) ?? .iPv4
    packetFlow?.writePackets([data], withProtocols: [NSNumber(value: version == .iPv4 ? AF_INET : AF_INET6)])
    bytesTransferred = bytesTransferred.incrementReceived(by: UInt32(data.count))
  }
}
/// IP protocol version detector
enum IPVersion: UInt8 {
  case iPv4 = 4
  case iPv6 = 6
  
  /// Scans packet data to determine IP version
  /// - Parameter data: Raw packet data
  /// - Returns: Detected IP version or nil if invalid
  static func scan(_ data: Data) -> Self? {
    guard data.count > 0 else { return nil }
    let version = (data.prefix(1) as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee >> 4
    return IPVersion(rawValue: version)
  }
}
