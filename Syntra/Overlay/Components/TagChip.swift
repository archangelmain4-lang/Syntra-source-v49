//
//  TagChip.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI

struct TagChip: View {
    let tag: Tag
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(Font.custom("SF Pro Display", size: 12))
                    .lineSpacing(15)
                    .foregroundColor(.white.opacity(0.56))
            }
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .frame(height: 28)
            .background(tag.darkerSwiftUIColor.opacity(0.75))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .inset(by: 0.25)
                    .stroke(tag.darkerSwiftUIColor, lineWidth: 0.25)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 