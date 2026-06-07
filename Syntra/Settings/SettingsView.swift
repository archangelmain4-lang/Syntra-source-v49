//
//  AIAssistView.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI
import Combine

// MARK: – ViewModifier that shifts view vertically by a fixed amount
struct SlideOffsetModifier: ViewModifier {
    let offsetY: CGFloat
    func body(content: Content) -> some View {
        content.offset(y: offsetY)
    }
}

extension AnyTransition {
    /// Slide from top by `distance` + asymmetric fade timing
    static func slightSlideFromTop(distance: CGFloat = 80) -> AnyTransition {
        // Base slide modifier
        let slide = AnyTransition.modifier(
            active: SlideOffsetModifier(offsetY: -distance),
            identity: SlideOffsetModifier(offsetY: 0)
        )

        let insertion = slide
            .combined(with: .opacity)
            .animation(.easeInOut(duration: 0.2))

        let removal = slide
            .combined(with: .opacity)
            .animation(.linear(duration: 0.1))

        return .asymmetric(insertion: insertion, removal: removal)
    }
}
// MARK: – Reusable row for a shortcut

/// A custom disclosure group with its indicator on the right.
struct RightArrowDisclosure<Label: View, Content: View>: View {
    /// Binding to control expanded state
    @Binding var isExpanded: Bool
    /// Label view for the header
    let label: Label
    /// Content to show when expanded
    let content: () -> Content

    init(isExpanded: Binding<Bool>,
         @ViewBuilder label: () -> Label,
         @ViewBuilder content: @escaping () -> Content) {
        self._isExpanded = isExpanded
        self.label = label()
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with text on left and chevron on right
            HStack {
                label
                Spacer()
                Image(systemName: "chevron.up")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            .padding(.vertical, 6)
            
            // Body content only when expanded
            if isExpanded {
                content()
                    .padding(.top, 8)
                // use custom slight slide instead of full move(edge:.top)
                    .transition(.slightSlideFromTop(distance: 50))
              }
        }
    }
}

struct ShortcutRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @State var keys = [String]()
    var hasToggle: Bool = false
    @Binding var isEditing: Bool
    @Binding var toggleOn: Bool
    @Binding var shortcut: Shortcut
    
    var editCallback: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                
                Text(title)
                Spacer()

                if isEditing{
                    Text("Recording...")
                        .foregroundStyle(.gray)
                        .font(.system(size: 10, weight: .light))
                        .padding(8).padding(.horizontal, 8)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.gray ,lineWidth: 1)
                        )

                }
                else{
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 16, height: 16)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(.lightGray) ,lineWidth: 1)
                            )
                    }
                }
                Button {
                    isEditing.toggle()
                    editCallback?(isEditing)
                } label: {
                    Image("icon_setting_shortcut_edit")
                        .contentShape(Rectangle())
                        .padding(8)
                        .background(colorScheme == .light ? .white : .black.opacity(0.5)).cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if hasToggle {
                HStack {
                    Text("|").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Use the screenshot shortcut inside Syntra Assist")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    Spacer()

                    // TODO: disabled until we implement
                    Toggle("", isOn: $toggleOn)
                        .labelsHidden().toggleStyle(.switch).scaleEffect(0.7)
                        .disabled(true)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: shortcut) { newValue in
            reload()
        }
        .onAppear{
            reload()
        }
    }
    func reload(){
        keys.removeAll()
        if shortcut.modifiers.contains(.command){
            keys.append("⌘")
        }
        if shortcut.modifiers.contains(.shift){
            keys.append("⇧")
        }
        if shortcut.modifiers.contains(.option){
            keys.append("⌥")
        }
        if shortcut.modifiers.contains(.control){
            keys.append("^")
        }
        keys.append(shortcut.key.uppercased())

    }
}

struct SelectionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool
    let baseColor: Color = Color(red: 0.94, green: 0.74, blue: 0.56)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // Ensure consistent button height across all appearance options
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isSelected
                            ? baseColor.opacity(0.3)
                        : colorScheme == .light ? .white : .black.opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected
                            ? baseColor
                            : Color.clear
                        ,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct SettingsView: View {
    var window: NSWindow?
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showShortcuts = true
    @State private var showVision = true
    @State private var showTheme = true
    @State private var showAdvanced = true
    @State private var showAccount = true
    @State private var showAPI = false
    
    @FocusState private var isTextFieldFocused: Bool

    @State private var editingAssistant = false
    @State private var editingCapture = false
    @State private var editingNotes = false

    private let shortcutModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    
    @ObservedObject var model = SettingsModel.shared
    @ObservedObject var inputEventModel = InputEventManager.shared.model
    @ObservedObject var authModel = AuthManager.shared.model
    
    private var currentAPIKey: Binding<String> {
        switch model.apiProvider {
        case .google:    return $model.keyGoogle
        case .azure:     return $model.keyAzure
        case .openAI:    return $model.keyOpenAI
        case .anthropic: return $model.keyAnthropic
        }
    }

    private var currentModelBinding: Binding<String> {
        switch model.apiProvider {
        case .openAI:    return $model.modelOpenAI
        case .google:    return $model.modelGoogle
        case .anthropic: return $model.modelAnthropic
        case .azure:     return $model.modelAzure
        }
    }
    
    var body: some View {
        VStack(spacing: 0){
            Color.clear.frame(height: 24)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {


                    RightArrowDisclosure(isExpanded: $showShortcuts){
                        Text("Customise Shortcuts")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    showShortcuts.toggle()
                                }
                            }
                    } content: {
                        VStack(spacing: 0) {
                            ShortcutRow(
                                title: "Syntra Assist",
                                isEditing: $editingAssistant,
                                toggleOn: .constant(false),
                                shortcut: $inputEventModel.aiAssistShortcut)
                                { edit in
                                    editingCapture = false
                                    editingNotes = false
                                    isTextFieldFocused = false
                                    if edit{
                                        InputEventManager.shared.requestCallback = { code in
                                            if code.modifiers.intersection(shortcutModifiers).isEmpty ||
                                                inputEventModel.screenshotShortcut == code
                                            {
                                                return false
                                            }
                                            DispatchQueue.main.async {
                                                inputEventModel.aiAssistShortcut = code
                                                self.editingAssistant = false
                                                InputEventManager.shared.setup()
                                            }
                                            return true
                                        }
                                    }
                                    else{
                                        InputEventManager.shared.requestCallback = nil
                                    }
                                    
                                }

                            ShortcutRow(
                                title: "Screenshot",
                                isEditing: $editingCapture,
                                toggleOn: .constant(false),
                                shortcut: $inputEventModel.screenshotShortcut)
                            { edit in
                                editingAssistant = false
                                editingNotes = false
                                isTextFieldFocused = false
                                if edit{
                                    InputEventManager.shared.requestCallback = { code in
                                        if code.modifiers.intersection(shortcutModifiers).isEmpty ||
                                            inputEventModel.aiAssistShortcut == code
                                        {
                                            return false
                                        }
                                        DispatchQueue.main.async {
                                            inputEventModel.screenshotShortcut = code
                                            self.editingCapture = false
                                            InputEventManager.shared.setup()
                                        }
                                        return true
                                    }
                                }
                                else{
                                    InputEventManager.shared.requestCallback = nil
                                }
                                
                            }

                        }
                        .padding(.top, 8)
                    }
                    
                    // MARK: Vision Mode
                    RightArrowDisclosure(isExpanded: $showVision) {
                        Text("Vision Mode")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { showVision.toggle() }
                            }
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Automatic screen awareness")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("When ON, Syntra captures your screen automatically every time it appears and keeps refreshing while open, so it already knows what you're looking at. No screenshot shortcut needed — just ask \"What is this?\".")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Toggle("", isOn: $model.visionModeEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            if model.visionModeEnabled {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Refresh interval")
                                        Spacer()
                                        Text("\(String(format: "%.1f", model.visionRefreshInterval))s")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $model.visionRefreshInterval, in: 1.0...8.0, step: 0.5)
                                    Text("How often Syntra silently re-reads the screen while the overlay is open. Lower = more up-to-date, higher = lighter on CPU.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: Theme
                    RightArrowDisclosure(isExpanded: $showTheme) {
                        Text("Theme")
                        // make the entire text area tappable
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // toggle expansion when text is tapped
                                withAnimation {
                                    showTheme.toggle()
                                }
                            }
                    } content: {
                        HStack {
                            Text("Appearance")
                            Spacer()
                            
                            HStack{
                                Button {
                                    withAnimation {
                                        model.appearance = .dawn
                                        NSApp.appearance = NSAppearance(
                                            named: .aqua
                                        )
                                    }
                                } label: {
                                    HStack {
                                        Image("icon_setting_appearance_light")
                                        if model.appearance == .dawn {
                                            Text("Dawn")
                                        }
                                    }
                                }
                                .buttonStyle(
                                    SelectionButtonStyle(isSelected: model.appearance == .dawn)
                                )

                                
                                Button {
                                    
                                    NSApp.appearance = NSAppearance(
                                        named: .darkAqua
                                    )
                                    withAnimation {
                                        model.appearance = .dark
                                    }
                                } label: {
                                    HStack {
                                        Image("icon_setting_appearance_dark")
                                        if model.appearance == .dark {
                                            Text("Dark")
                                        }
                                    }
                                }
                                .buttonStyle(
                                    SelectionButtonStyle(isSelected: model.appearance == .dark)
                                )

                                Button {
                                    NSApp.appearance = nil
                                    withAnimation {
                                        model.appearance = .automatic
                                    }
                                } label: {
                                    HStack {
                                        Image("icon_setting_appearance_auto")
                                        if model.appearance == .automatic {
                                            Text("Auto")
                                        }
                                    }
                                }
                                .buttonStyle(
                                    SelectionButtonStyle(isSelected: model.appearance == .automatic)
                                )
                            }
                        }
                        .padding(.vertical, 8)

                        // Overlay glass — slider lets the user choose how
                        // transparent the floating window/pill background is.
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Overlay Glass")
                                Spacer()
                                Text(model.overlayGlassOpacity >= 0.95 ? "Solid"
                                     : model.overlayGlassOpacity <= 0.15 ? "Max Glass"
                                     : "\(Int(model.overlayGlassOpacity * 100))%")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $model.overlayGlassOpacity, in: 0.1...1.0)
                            Text("Lower = more see-through. Higher = more solid.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: Advanced (API key only — no custom endpoint)
                    RightArrowDisclosure(isExpanded: $showAdvanced) {
                        Text("Advanced")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { showAdvanced.toggle() }
                            }
                    } content: {
                        VStack(spacing: 16) {
                            HStack {
                                Text("AI Provider")
                                Spacer()
                                Menu {
                                    ForEach(APIProvider.allCases) { type in
                                        Button(type.rawValue) {
                                            model.apiProvider = type
                                            switch type {
                                            case .openAI:    model.customAPIKey = model.keyOpenAI
                                            case .google:    model.customAPIKey = model.keyGoogle
                                            case .anthropic: model.customAPIKey = model.keyAnthropic
                                            case .azure:     model.customAPIKey = model.keyAzure
                                            }
                                        }
                                    }
                                } label: {
                                    Text(model.apiProvider.rawValue)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .menuStyle(BorderlessButtonMenuStyle())
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                )
                                .frame(width: 200)
                            }

                            HStack {
                                Text("Model")
                                Spacer()
                                Menu {
                                    ForEach(model.apiProvider.availableModels, id: \.self) { m in
                                        Button(m) { currentModelBinding.wrappedValue = m }
                                    }
                                } label: {
                                    Text(currentModelBinding.wrappedValue.isEmpty
                                         ? model.apiProvider.defaultModel
                                         : currentModelBinding.wrappedValue)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .menuStyle(BorderlessButtonMenuStyle())
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                )
                                .frame(width: 200)
                            }

                            HStack {
                                Text("API Key")
                                Spacer()
                                SecureField("Paste API Key", text: currentAPIKey)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .frame(width: 220)
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6).fill(
                                            colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                    )
                                    .focused($isTextFieldFocused)
                                    .onChange(of: currentAPIKey.wrappedValue) { newValue in
                                        model.customAPIKey = newValue
                                    }
                            }

                            Text("Your API key is stored locally on this Mac and used only to call your chosen AI provider directly.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 8)
                    }

                    // MARK: Account
                    RightArrowDisclosure(isExpanded: $showAccount) {
                        Text("Account")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { showAccount.toggle() }
                            }
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            if authModel.isAuthenticated {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Signed in as")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Text(authModel.email ?? "—")
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                }

                                HStack {
                                    Button {
                                        if let url = URL(string: "https://syntra.cc/") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } label: { Text("Manage Account") }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                            .opacity(0.5)
                                    )
                                    Spacer()
                                    Button {
                                        AuthManager.shared.logout()
                                    } label: {
                                        Text("Log Out").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                            .opacity(0.5)
                                    )
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Button {
                                        AuthManager.shared.startAuthFlow()
                                    } label: { Text("Log In") }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(colorScheme == .light ? Color.white : Color.black.opacity(0.5))
                                            .opacity(0.5)
                                    )
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }


                    Spacer()
                    HStack{
                        Spacer()
                        Image("icon_setting_logo")
                        Spacer()
                    }
                }
                .padding(20)
            }
        }

        .onAppear{
            DispatchQueue.main.async{
                isTextFieldFocused = false
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .inset(by: 0.5)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .ignoresSafeArea(edges: .top)
    }
    
}

#Preview {
    SettingsView(window: nil)
        .frame(width: 500, height: 520).background(.white)
}
