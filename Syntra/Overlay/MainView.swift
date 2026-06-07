//
//  MainView.swift
//  ProtoType1
//
//  Created by occlusion on 4/28/25.
//


import SwiftUI

private extension View {
    @ViewBuilder
    func scrollIndicatorsHiddenIfAvailable() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollIndicators(.hidden)
        } else {
            self
        }
    }
}

struct DarkBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .dark
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // nothing to update
    }
}

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "New idea about the meaning of joy..."
    var shortcut: String = "cmd+/"
    
    var body: some View {
        HStack(spacing: 0) {
            // 1) The text field
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 18))
                .padding(.vertical, 8)
                .padding(.leading, 16)
            
            Spacer(minLength: 0)
            
            // 2) The shortcut badge
            Text(shortcut)
                .font(.system(size: 14))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    // semi-opaque rounded rect
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1)).allowsHitTesting(false)
                )
                .foregroundColor(.white)
                .padding(.trailing, 12)
        }
        .frame(height: 72)
        .background(DarkBlur()).cornerRadius(36)
        .overlay(
            // subtle outer stroke if desired
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}


struct OverlayBubble: View {
    let text: String
    let tagText: String
    let tagColor: Color
    
    let menuItems: [String]
    let onTagTap: () -> Void
    let onMenuSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main text
            Text(text)
                .font(.system(size: 20))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                // Tag as a button
                Button(action: onTagTap) {
                    Text(tagText)
                        .font(.system(size: 12))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagColor.opacity(0.85))
                        .foregroundColor(Color(white:0.33))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle()) // Remove default button styling
                
                Menu {
                    ForEach(menuItems, id: \.self) { item in
                        Button(item) {
                            onMenuSelect(item)
                        }
                    }
                } label: {
                    Text("Select Tags")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    // Apply dashed stroke as background
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    style: StrokeStyle(
                                        lineWidth: 1,
                                        lineCap: .round,
                                        dash: [4, 4]
                                    )
                                )
                                .foregroundColor(Color.white.opacity(0.6))
                        )
                }
                .frame(maxWidth: 80)
                .menuStyle(BorderlessButtonMenuStyle())                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4])
                        )
                        .foregroundColor(Color.white.opacity(0.6))
                )                        }
        }
        .padding(24)
        .background(DarkBlur())
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 1000)
    }
}


struct PreviewCard: View{
    var body: some View {
        VStack{
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("purest from of generosity. What would it feel like to offer that kind of generosity to the world, and oursevlves?")
                        .font(.body)
                        .foregroundColor(.black)
                    
                    Text("A premonition of joy")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    HStack(alignment: .top, spacing: 16) {
                        
                        Image("preImage")
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(maxWidth: 200)
                            .cornerRadius(8)
                        
                        Text(
                        """
                        Echoes of Japanese wisdom can be found across centuries and cultures: the ancient Stoics, who believed that living in harmony with ourselves enables us to live in harmony with the universe; the mystics, who called gratitude the highest form of prayer; the poets, who instruct us, over and over again, to keep our eyes and hearts open.
                        """
                        )
                        .font(.body)
                        .foregroundColor(.black)
                    }
                    
                    Text(
                    """
                    Perhaps then, a good life invites us to move through our days with a gentle anticipation of some or other joy.
                    """
                    )
                    .font(.body)
                    .foregroundColor(.black)
                }
                .padding(24)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding()
            }
            .scrollIndicatorsHiddenIfAvailable()
            .background(Color.clear.edgesIgnoringSafeArea(.all))
            .background(Color.white)
            .cornerRadius(6)
        }.padding(4)
            .background(Color(red:0.5, green:1.0, blue:0.5).opacity(0.15).edgesIgnoringSafeArea(.all))
            .cornerRadius(6)
    }
    
}

struct MainView: View {
    
    @State var query = ""
    
    @State private var newValue: String = ""
    var body: some View {
        VStack{
            GeometryReader { geo in
                
                ZStack {

                    SearchBarView(text: $query)
                        .frame(width: 500)
                        .position(x: geo.size.width/2,
                                  y: 0)
                    
                    OverlayBubble(
                        text: "Stoics, mystics, they all are quite similar",
                        tagText: "Realizations",
                        tagColor: .red,
                        menuItems: ["Tag A", "Tag B", "Tag C"],
                        onTagTap: {
                            print("Realizations tapped")
                        },
                        onMenuSelect: { selection in
                            print("Selected \(selection)")
                        }
                    )
                    .position(x: 160,
                              y: geo.size.height * 0.33)
                    
                    OverlayBubble(
                        text: "Joyful thinking leads to better results throughout",
                        tagText: "Interface Design",
                        tagColor: .green,
                        menuItems: ["Tag A", "Tag B", "Tag C"],
                        onTagTap: {
                            print("Realizations tapped")
                        },
                        onMenuSelect: { selection in
                            print("Selected \(selection)")
                        }
                        
                    )
                    .position(x: geo.size.width - 180,
                              y: geo.size.height * 0.4)
                    
                    
                    OverlayBubble(
                        text: "Remember my daily premonition meditation",
                        tagText: "Reminders",
                        tagColor: .purple,
                        menuItems: ["Tag A", "Tag B", "Tag C"],
                        onTagTap: {
                            print("Realizations tapped")
                        },
                        onMenuSelect: { selection in
                            print("Selected \(selection)")
                        }
                        
                    )
                    .position(x: geo.size.width-300,
                              y: geo.size.height * 0.7)
                    
                }
                .background(Color.clear)
            }
        }
        .padding(EdgeInsets(top: 40, leading: 80, bottom: 40, trailing: 80))
    }
}

#Preview(body: {
    MainView().frame(width: 1000, height: 700)
})

