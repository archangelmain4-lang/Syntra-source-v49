//
//  Tag.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import SwiftUI
import CoreGraphics

struct Tag: Identifiable, Codable, Equatable {
    let id = UUID()
    let uniqueid: String
    let name: String
    let color: String
    
    // New tag colors from the database
    static let NEW_TAG_COLORS = [
        "#EA9280",
        "#FA934E", 
        "#EBBC00",
        "#94BA2C",
        "#65BA75",
        "#2EBDE5",
        "#E38EC3"
    ]
    
    // Computed property to convert color string to SwiftUI Color
    var swiftUIColor: Color {
        return Color(hex: color) ?? .gray
    }
    
    // Computed property to get a darker variant of the color for better contrast
    var darkerSwiftUIColor: Color {
        guard let color = Color(hex: self.color) else { return .gray }
        return color.darkerVariant()
    }
}

// Extension to support hex color parsing
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Extension to create a darker variant of the color without relying on UIKit
    func darkerVariant(by factor: Double = 0.7) -> Color {
        guard let cgColor = self.cgColor else { return self }
        // Convert to sRGB color space for predictable component order (R, G, B, A)
        guard let converted = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let comps = converted.components, comps.count >= 3 else {
            return self
        }
        let r = Double(comps[0])
        let g = Double(comps[1])
        let b = Double(comps[2])
        // Alpha may be omitted in some color spaces, default to 1.0
        let a = Double(comps.count >= 4 ? comps[3] : 1.0)

        return Color(
            .sRGB,
            red: max(0.0, r * factor),
            green: max(0.0, g * factor),
            blue: max(0.0, b * factor),
            opacity: a
        )
    }
} 
