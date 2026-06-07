//
//  SettingsModel.swift
//  Syntra
//

import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case dawn, dark, automatic
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .dawn: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .automatic: return "circle.lefthalf.fill"
        }
    }
}

enum APIProvider: String, CaseIterable, Identifiable {
    case openAI    = "OpenAI"
    case google    = "Google (Gemini)"
    case anthropic = "Anthropic (Claude)"
    case azure     = "Azure"

    var id: String { rawValue }

    /// Models the user can pick from for this provider.
    var availableModels: [String] {
        switch self {
        case .openAI:
            return [
                "gpt-4o-mini",
                "gpt-4o",
                "gpt-4-turbo",
                "gpt-4.1",
                "gpt-4.1-mini",
                "gpt-5",
                "gpt-5-mini",
                "o1-mini",
                "o3-mini"
            ]
        case .google:
            return [
                "gemini-2.5-flash",
                "gemini-2.5-pro",
                "gemini-2.5-flash-lite",
                "gemini-1.5-flash",
                "gemini-1.5-pro"
            ]
        case .anthropic:
            return [
                "claude-3-5-sonnet-latest",
                "claude-3-5-haiku-latest",
                "claude-3-opus-latest",
                "claude-sonnet-4-20250514"
            ]
        case .azure:
            return [
                "gpt-4o-mini",
                "gpt-4o",
                "gpt-4-turbo"
            ]
        }
    }

    var defaultModel: String { availableModels.first ?? "" }
}

class SettingsModel: ObservableObject {
    @AppStorage("Appearance") var appearance: Appearance = .automatic
    @AppStorage("ShowRelatedNotes") var showRelatedNotes: Bool = true

    /// Glass / opacity of the floating overlay shell. 0 = fully transparent
    /// (max glass), 1 = solid material. Adjustable from Settings.
    @AppStorage("OverlayGlassOpacity") var overlayGlassOpacity: Double = 0.82

    /// Vision Mode — when ON, Syntra automatically captures the screen on
    /// summon AND periodically refreshes context while the overlay is open,
    /// so the AI always knows what the user is currently looking at. When
    /// OFF, screen context is captured only once at summon time.
    @AppStorage("VisionModeEnabled") var visionModeEnabled: Bool = true
    /// How often Vision Mode refreshes screen context while open (seconds).
    @AppStorage("VisionRefreshInterval") var visionRefreshInterval: Double = 2.5

    // Provider + per-provider API keys
    @AppStorage("APIProvider") var apiProvider: APIProvider = .openAI
    @AppStorage("APIKey_OpenAI")    var keyOpenAI: String = ""
    @AppStorage("APIKey_Google")    var keyGoogle: String = ""
    @AppStorage("APIKey_Anthropic") var keyAnthropic: String = ""
    @AppStorage("APIKey_Azure")     var keyAzure: String = ""

    // Per-provider model selection
    @AppStorage("Model_OpenAI")    var modelOpenAI: String    = "gpt-4o-mini"
    @AppStorage("Model_Google")    var modelGoogle: String    = "gemini-2.5-flash"
    @AppStorage("Model_Anthropic") var modelAnthropic: String = "claude-3-5-sonnet-latest"
    @AppStorage("Model_Azure")     var modelAzure: String     = "gpt-4o-mini"

    // Custom backend (sent to APIConfig)
    @AppStorage("CustomAPIBaseURL") var customBaseURL: String = ""
    /// Mirrors the per-provider key into the unified slot APIConfig reads.
    @AppStorage("CustomAPIKey") var customAPIKey: String = ""

    static let shared = SettingsModel()

    func currentModel() -> String {
        switch apiProvider {
        case .openAI:    return modelOpenAI.isEmpty    ? apiProvider.defaultModel : modelOpenAI
        case .google:    return modelGoogle.isEmpty    ? apiProvider.defaultModel : modelGoogle
        case .anthropic: return modelAnthropic.isEmpty ? apiProvider.defaultModel : modelAnthropic
        case .azure:     return modelAzure.isEmpty     ? apiProvider.defaultModel : modelAzure
        }
    }
}
