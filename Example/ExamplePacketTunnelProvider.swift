//
//
// SimplePacketTunnelProvider.swift
//
// Developed by Dmitry Ulyanov
//

import NetworkExtension
import SwiftyXrayKit
import Network

// MARK: - Packet Tunnel Provider
/// A Network Extension provider that handles VPN tunnel connections using XRay
class ExamplePacketTunnelProvider: NEPacketTunnelProvider {
  
  struct NetworkInterfaceInfo {
    let name: String
    let ip: String
    let netmask: String
  }
  
  // MARK: - Error Types
  /// Custom errors for packet tunnel operations
  enum PacketTunnelError: Error {
    case defaultError
  }
  
  // MARK: - Properties
  /// The XRay tunnel client instance that handles the actual proxy connection
  var xrayClient: XRayTunnel?
  
  // MARK: - Tunnel Lifecycle Methods
  
  /// Called when the system requests to start the VPN tunnel
  /// - Parameters:
  ///   - options: Configuration options passed from the main app
  ///   - completionHandler: Callback to indicate success or failure of tunnel start
  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    // Configure the network settings for the tunnel (IP addresses, DNS, routes, etc.)
    setTunnelNetworkSettings(generateNetworkSettings()) { error in
      // Check if network settings configuration failed
      guard error == nil else {
        completionHandler(error)
        return
      }
      
      // Start the XRay proxy service
      self.startXrayAndSocksProxy(completionHandler)
    }
  }

  /// Initializes and starts the XRay tunnel with configuration
  /// - Parameter completion: Optional callback to handle the result of starting XRay
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
  
  /// Called when the system requests to stop the VPN tunnel
  /// - Parameters:
  ///   - reason: The reason why the tunnel is being stopped
  ///   - completionHandler: Callback to indicate tunnel has been stopped
  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    // Delegate to private stop method
    self.stopTunnel(completionHandler: completionHandler)
  }
  
  /// Handles the actual tunnel stopping process
  /// - Parameter completionHandler: Callback to indicate tunnel has been stopped
  private func stopTunnel(completionHandler: @escaping () -> Void) {
    Task {
      // Stop the XRay client gracefully
      await xrayClient?.stop()
      
      // Notify that tunnel has been stopped
      completionHandler()
    }
  }
}

// MARK: - Helpers
extension ExamplePacketTunnelProvider {

  func generateNetworkSettings() -> NEPacketTunnelNetworkSettings {
    
    // find unused ipv4 address in range 10.x.x.x (it's just example)
    let interfaces = enumerateInterfaces().map{ $0.ip }.filter({ $0.isIPv4() })
    var net = 5
    var found = false
    while !found {
      if !interfaces.contains(where: { $0.hasPrefix("10.\(net)") }) {
        found = true
      } else {
        net += 1
      }
    }
    let localIp = "10.\(net).5.2"
    
    let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
    networkSettings.mtu = 1360
    
    let ipv4Settings = NEIPv4Settings(addresses: [localIp], subnetMasks: ["255.255.255.255"])
    
    ipv4Settings.includedRoutes = [NEIPv4Route.default()]
    ipv4Settings.excludedRoutes = [NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
                                   NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
                                   NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0")]
    
    networkSettings.ipv4Settings = ipv4Settings
    networkSettings.dnsSettings = NEDNSSettings(servers: ["127.0.0.1", "1.1.1.1", "8.8.8.8",])
    return networkSettings
  }
  
  func enumerateInterfaces() -> [NetworkInterfaceInfo] {
    var interfaces = [NetworkInterfaceInfo]()
    
    // Get list of all interfaces on the local machine:
    var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
      // For each interface ...
      var ptr = ifaddr
      while( ptr != nil) {
        
        let flags = Int32(ptr!.pointee.ifa_flags)
        var addr = ptr!.pointee.ifa_addr.pointee
        
        // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
        if (flags & (IFF_UP|IFF_RUNNING)) == (IFF_UP|IFF_RUNNING) {
          if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
            
            var mask = ptr!.pointee.ifa_netmask.pointee
            
            // Convert interface address to a human readable string:
            let zero  = CChar(0)
            var hostname = [CChar](repeating: zero, count: Int(NI_MAXHOST))
            
            var netmask =  [CChar](repeating: zero, count: Int(NI_MAXHOST))
            if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
              let address = String(cString: hostname)
              let name = ptr!.pointee.ifa_name!
              let ifname = String(cString: name)
              
              
              if (getnameinfo(&mask, socklen_t(mask.sa_len), &netmask, socklen_t(netmask.count),
                              nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                let netmaskIP = String(cString: netmask)
                
                let info = NetworkInterfaceInfo(name: ifname,
                                                ip: address,
                                                netmask: netmaskIP)
                interfaces.append(info)
              }
            }
          }
        }
        ptr = ptr!.pointee.ifa_next
      }
      freeifaddrs(ifaddr)
    }
    return interfaces
  }
}

// MARK: - FileManager Extension
/// Extension to provide easy access to the app's document directory
extension FileManager {
  /// Returns the document directory URL for the current user
  var documentDirectory: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }
}

extension String {
  func isIPv4() -> Bool {
    var sin = sockaddr_in()
    return self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1
  }
  
  func isIPv6() -> Bool {
    var sin6 = sockaddr_in6()
    return self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1
  }
  
  func isIpAddress() -> Bool { return self.isIPv6() || self.isIPv4() }
}
