import SwiftUI

public enum FontVariations: Int, CustomStringConvertible {
    // Magic numbers for the various axes available for variable font control
    case weight = 2003265652
    case width = 2003072104
    case opticalSize = 1869640570
    case grad = 1196572996
    case slant = 1936486004
    case xtra = 1481921089
    case xopq = 1481592913
    case yopq = 1498370129
    case ytlc = 1498696771
    case ytuc = 1498699075
    case ytas = 1498693971
    case ytde = 1498694725
    case ytfi = 1498695241

    public var description: String {
        switch self {
        case .weight:
            return "Weight"
        case .width:
            return "Width"
        case .opticalSize:
            return "Optical Size"
        case .grad:
            return "Grad"
        case .slant:
            return "Slant"
        case .xtra:
            return "Xtra"
        case .xopq:
            return "Xopq"
        case .yopq:
            return "Yopq"
        case .ytlc:
            return "Ytlc"
        case .ytuc:
            return "Ytuc"
        case .ytas:
            return "Ytas"
        case .ytde:
            return "Ytde"
        case .ytfi:
            return "Ytfi"
        }
    }
}

extension Font {
    static let syncopate = Font.custom("Syncopate", size: 16)
    
    // MARK: - Debug function to test font availability
    static func debugFontAvailability() {
        let availableFonts = NSFontManager.shared.availableFontFamilies
        print("=== FONT DEBUG ===")
        print("Available font families containing 'Inter':")
        for family in availableFonts {
            if family.lowercased().contains("inter") {
                print("- \(family)")
                let fonts = NSFontManager.shared.availableMembers(ofFontFamily: family)
                print("  Members: \(fonts?.map { $0[0] } ?? [])")
            }
        }
        
        // Test Inter font creation
        if let interFont = NSFont(name: "Inter", size: 16) {
            print("✅ Inter font loaded successfully: \(interFont.fontName)")
        } else {
            print("❌ Inter font not available")
        }
        
        // Test Inter italic font creation
        if let interItalicFont = NSFont(name: "Inter-Italic", size: 16) {
            print("✅ Inter-Italic font loaded successfully: \(interItalicFont.fontName)")
        } else {
            print("❌ Inter-Italic font not available")
        }
        print("==================")
    }
    
    // MARK: - Inter Font Base Function
    static func inter(_ size: CGFloat, axis: [FontVariations: Double] = [:]) -> Font {
        // Transform the incoming axis map, which uses the enum for the axis to a type of `[Int: Double]`
        // which is what `NSFontDescriptor` requires.
        let intAxis: [Int: Double] = .init(uniqueKeysWithValues: axis.map { (key, value) in
            return (key.rawValue, value)
        })
        
        // Try variable font approach first
        let fontDescriptor = NSFontDescriptor(fontAttributes: [
            .name: "Inter",
            .variation: intAxis
        ])
        
        if let nsFont = NSFont(descriptor: fontDescriptor, size: size) {
            return Font(nsFont)
        } else {
            // Fallback to regular Inter font
            return Font.custom("Inter", size: size)
        }
    }
    
    // MARK: - Inter 100 Weight (Thin)
    static func inter100Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Thin", size: size)
    }
    
    static func inter100Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_Thin-Italic", size: size)
    }
    
    static func inter100Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 200 Weight (ExtraLight)
    static func inter200Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_ExtraLight", size: size)
    }
    
    static func inter200Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_ExtraLight-Italic", size: size)
    }
    
    static func inter200Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 300 Weight (Light)
    static func inter300Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Light", size: size)
    }
    
    static func inter300Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_Light-Italic", size: size)
    }
    
    static func inter300Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 400 Weight (Regular)
    static func inter400Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular", size: size)
    }
    
    static func inter400Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic", size: size)
    }
    
    static func inter400Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 500 Weight (Medium)
    static func inter500Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Medium", size: size)
    }
    
    static func inter500Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_Medium-Italic", size: size)
    }
    
    static func inter500Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 600 Weight (SemiBold)
    static func inter600Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_SemiBold", size: size)
    }
    
    static func inter600Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_SemiBold-Italic", size: size)
    }
    
    static func inter600Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    // MARK: - Inter 700 Weight (Bold)
    static func inter700Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Bold", size: size)
    }
    
    static func inter700Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_Bold-Italic", size: size)
    }
    
    static func inter700Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_ExtraBold", size: size)
    }
    
    // MARK: - Inter 800 Weight (ExtraBold)
    static func inter800Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_ExtraBold", size: size)
    }
    
    static func inter800Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_ExtraBold-Italic", size: size)
    }
    
    static func inter800Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Black", size: size)
    }
    
    // MARK: - Inter 900 Weight (Black)
    static func inter900Regular(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Black", size: size)
    }
    
    static func inter900Italic(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Italic_Black-Italic", size: size)
    }
    
    static func inter900Bold(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular_Black", size: size)
    }
}
