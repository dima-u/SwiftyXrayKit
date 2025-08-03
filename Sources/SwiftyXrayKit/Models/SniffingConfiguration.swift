//
// SniffingConfiguration.swift
// XrayWrapper
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

/// Configuration for Xray traffic sniffing capabilities
public struct SniffingConfiguration: Codable {
  /// Destination override protocols (e.g., "http", "tls", "quic", "fakedns")
  public let destOverride: [String]
  
  /// Whether sniffing is enabled
  public let enabled: Bool
  
  /// Whether to route only sniffed traffic
  public let routeOnly: Bool
  
  /// Domains to exclude from sniffing
  public let domainsExcluded: [String]
  
  /// Whether to only extract metadata without content
  public let metadataOnly: Bool
  
  enum CodingKeys: String, CodingKey {
    case destOverride = "destOverride"
    case enabled = "enabled"
    case routeOnly = "routeOnly"
    case metadataOnly = "metadataOnly"
    case domainsExcluded = "domainsExcluded"
  }
  
  /// Creates a new SniffingConfiguration
  /// - Parameters:
  ///   - destOverride: Array of destination override protocols
  ///   - enabled: Enable/disable sniffing
  ///   - routeOnly: Route only sniffed traffic
  ///   - domainsExcluded: Domains to exclude from sniffing
  ///   - metadataOnly: Extract only metadata
  public init(
    destOverride: [String],
    enabled: Bool,
    routeOnly: Bool,
    domainsExcluded: [String],
    metadataOnly: Bool
  ) {
    self.destOverride = destOverride
    self.enabled = enabled
    self.routeOnly = routeOnly
    self.domainsExcluded = domainsExcluded
    self.metadataOnly = metadataOnly
  }
}
