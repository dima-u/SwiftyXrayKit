//
// String+Base64.swift
// XrayWrapper
//
// Copyright © 2025 Dmitry Ulyanov
//

import Foundation

extension String {
  /// Decodes a base64 encoded string to plain text
  /// - Returns: Decoded string or nil if decoding fails
  func fromBase64() -> String? {
    guard let data = Data(base64Encoded: self) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }
  
  /// Encodes the string to base64
  /// - Returns: Base64 encoded string
  func toBase64() -> String {
    return Data(self.utf8).base64EncodedString()
  }
}
