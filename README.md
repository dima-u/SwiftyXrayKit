# SwiftyXrayKit

A Swift wrapper and ready to use PacketTunnelProvider primitives for Xray-core functionality, providing easy-to-use APIs for iOS and macOS applications.

[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Swift 6.0](https://img.shields.io/badge/language-Swift6.0-orange.svg?style=flat)](https://developer.apple.com/swift)
![Build](https://github.com/dima-u/SwiftyXrayKit/actions/workflows/swift.yml/badge.svg)

## Overview

SwiftyXrayKit provides a clean Swift interface to Xray-core functionality through two main components:

- **SwiftyXrayCore**: Binary framework package containing the XrayApple.xcframework
- **SwiftyXrayKit**: Swift wrapper providing high-level APIs for Xray operations

## Features

- ✅ Port allocation management
- ✅ Xray configuration and lifecycle management  
- ✅ Share link to JSON conversion (VMess, VLESS, etc.)
- ✅ Network tunnel integration for VPN functionality
- ✅ iOS and macOS support
- ✅ geo-site and geo-ip downloader

## Installation

### Swift Package Manager

Add SwiftyXrayKit to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftyXrayKit.git", from: "1.0.0")
]
```

## Usage

1. Create a Packet Tunnel Provider

```swift
import NetworkExtension
import SwiftyXrayKit

class SimplePacketTunnelProvider: NEPacketTunnelProvider {
  
  enum PacketTunnelError: Error {
    case defaultError
  }

  var xrayClient: XRayTunnel?
}
```

2. Implement Tunnel Lifecycle Methods

Starting the Tunnel

Override startTunnel(options:completionHandler:) to configure network settings and start XRay:

```swift
override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
  // Configure the network settings for the tunnel (IP addresses, DNS, routes, etc.)
  setTunnelNetworkSettings(networkSettings) { error in
    guard error == nil else {
      completionHandler(error)
      return
    }
    
    // Start the XRay proxy service
    self.startXrayAndSocksProxy(completionHandler)
  }
}
```

XRay Initialization and Configuration

```swift
private func startXrayAndSocksProxy(_ completion: ((Error?)->Void)? = nil) {
  // Path to GeoIP database files (used for routing decisions)
  let geoIpPath = FileManager.default.documentDirectory
  
  // Path to the XRay configuration file
  let configPath = FileManager.default.documentDirectory.appending(path: "config.json")
  
  // Initialize XRay tunnel with the packet flow from Network Extension
  xrayClient = XRayTunnel(packetFlow: packetFlow)
  
  // Start XRay asynchronously
  Task {
    do {
      // Read the configuration file content
      let config = try String(contentsOf: configPath, encoding: .utf8)
      
      // Path where the final processed configuration will be saved
      let finalPath = FileManager.default.documentDirectory.appending(path: "config_final.json")
      
      // Start the XRay tunnel with the configuration
      try await xrayClient?.run(dataDir: geoIpPath, config: .json(config), finalConfigPath: finalPath)
      
      // Notify success
      completion?(nil)
    } catch {
      print("error: \(error)")
      // Notify failure
      completion?(error)
    }
  }
}
```

Stopping the Tunnel

```swift
override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
  self.stopTunnel(completionHandler: completionHandler)
}

private func stopTunnel(completionHandler: @escaping () -> Void) {
  Task {
    // Stop the XRay client gracefully
    await xrayClient?.stop()
    
    // Notify that tunnel has been stopped
    completionHandler()
  }
}
```

4. Configuration Requirements

Before starting the tunnel, ensure you have:

1.  XRay Configuration File: Place your config.json file in the document directory
2.  GeoIP Database: Ensure GeoIP files are available in the document directory. You can use `GeoFilesLoader` to download GeoIp files.
3.  Network Settings: Configure networkSettings with appropriate IP addresses, DNS servers, and routes


This implementation provides a robust VPN solution using XRay-core through SwiftyXrayKit, with proper lifecycle management and error handling.

License

SwiftyXrayKit is released under the Apache 2.0 License. See the LICENSE file for details.
