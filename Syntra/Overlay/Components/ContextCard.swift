//
//  ContextCard.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI

struct ContextCard: View {
    let text: String
    let tags: [Tag]
    let menuItems: [String]
    let onTagTap: (Tag) -> Void
    let onMenuSelect: (String) -> Void
    var isDragging: Bool = false
    
    @State private var isHovering = false
    
    // Computed property to limit text to 150 words
    private var limitedText: String {
        let words = text.split(separator: " ")
        if words.count > 150 {
            return words.prefix(150).joined(separator: " ") + "..."
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Drag handle indicator
            HStack {
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(Color.black.opacity(isDragging ? 0.6 : 0.3))
                Spacer()
            }
            .padding(.top, -8)
            
            Text(limitedText)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.91))
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(alignment: .top, spacing: 4) {
                ForEach(tags, id: \.uniqueid) { tag in
                    TagChip(tag: tag, onTap: {
                        onTagTap(tag)
                    })
                }
                
                // Menu for additional tag selection
                // if !menuItems.isEmpty {
                //     Menu {
                //         ForEach(menuItems, id: \.self) { item in
                //             Button(item) {
                //                 onMenuSelect(item)
                //             }
                //         }
                //     } label: {
                //         HStack(spacing: 4) {
                //             Image(systemName: "plus")
                //                 .font(.system(size: 10))
                //                 .foregroundColor(.white.opacity(0.6))
                //             Text("Add")
                //                 .font(Font.custom("SF Pro Display", size: 12))
                //                 .lineSpacing(15)
                //                 .foregroundColor(.white.opacity(0.6))
                //         }
                //         .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                //         .frame(height: 28)
                //         .background(Color.clear)
                //         .cornerRadius(6)
                //         .overlay(
                //             RoundedRectangle(cornerRadius: 6)
                //                 .inset(by: 0.25)
                //                 .stroke(
                //                     style: StrokeStyle(lineWidth: 0.5, dash: [2, 2])
                //                 )
                //                 .foregroundColor(.white.opacity(0.4))
                //         )
                //     }
                //     .menuStyle(BorderlessButtonMenuStyle())
                // }
            }
        }
        .padding(12)
        .frame(minWidth: 256, maxWidth: 256)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowYOffset)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    // MARK: - Computed values for visuals
    private var shadowOpacity: Double {
        isDragging ? 0.2 : 0.1
    }
    private var shadowRadius: CGFloat {
        isDragging ? 12 : 8
    }
    private var shadowYOffset: CGFloat {
        isDragging ? 6 : 4
    }
}

#Preview {
    let sampleTags = [
        Tag(uniqueid: "1", name: "Buddhism Philosophy", color: "#EA9280"),
        Tag(uniqueid: "2", name: "Philosophy", color: "#FA934E")
    ]
    
    ContextCard(
        text: "My thoughts and way of looking at life is quite in align how buddhism puts it into explanation of what life really is",
        tags: sampleTags,
        menuItems: ["Tag A", "Tag B", "Tag C"],
        onTagTap: { tag in
            print("Tag tapped: \(tag.name)")
        },
        onMenuSelect: { selection in
            print("Selected \(selection)")
        },
        isDragging: false
    )
    .padding()
    .background(Color.gray.opacity(0.1))
} 
