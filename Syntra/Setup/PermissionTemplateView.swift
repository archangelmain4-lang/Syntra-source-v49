//
//  PermissionTemplateView.swift
//  Syntra
//
//  Created by occlusion on 5/4/25.
//

import SwiftUI

struct PermissionTemplateView: View {
    let title: String
    let subtitle: String
    let isPermissionGranted: Bool
    let onGrantAccess: () -> Void
    let onNeedHelp: () -> Void
    let onNextStep: () -> Void
    let image: String
    var manualContinueTitle: String? = nil
    var onManualContinue: (() -> Void)? = nil
    var restartTitle: String? = nil
    var onRestart: (() -> Void)? = nil
    
    @State private var isHelpExpanded: Bool = false

    let leftSideWidth: CGFloat = 0.6
    let rightSideWidth: CGFloat = 0.35
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - Placeholder image 
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width * leftSideWidth, height: geometry.size.height, alignment: .trailing)
                    .clipped()
                
                // Right side content (remaining 1/4 width)
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 32) {
                        // Main title text with top padding - full remaining width
                        Text(title)
                            .font(Font.custom("SF Pro Display", size: 34).weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 26)
                        
                        Text(subtitle)
                            .font(Font.custom("SF Pro Display", size: 13))
                            .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.48))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        
                        // Collapsible Help Section
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHelpExpanded.toggle()
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 10) {
                                    HStack(alignment: .top, spacing: 4) {
                                        ZStack() {
                                            Text(isHelpExpanded ? "􀅍" : "?")
                                                .font(Font.custom("SF Pro", size: 10.40).weight(.medium))
                                                .lineSpacing(12.80)
                                                .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.48))
                                                .offset(x: 0.10, y: -0.30)
                                        }
                                        .frame(width: 16, height: 16)
                                        .background(Color(red: 0, green: 0, blue: 0).opacity(0.09))
                                        .cornerRadius(80)
                                        
                                        Text("How to enable screen access")
                                            .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                            .lineSpacing(16)
                                            .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.48))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isHelpExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.48))
                                        .frame(width: 20, height: 20)
                                }
                                
                                if isHelpExpanded {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // MS Teams row
                                        HStack(spacing: 59) {
                                            HStack(spacing: 4) {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 18, height: 18)
                                                    .background(.white)
                                                    .cornerRadius(4.50)
                                                Text("MS Teams")
                                                    .font(Font.custom("SF Pro Display", size: 13))
                                                    .lineSpacing(16)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            ZStack() {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 13, height: 13)
                                                    .background(.white)
                                                    .cornerRadius(100)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 100)
                                                            .inset(by: -0.25)
                                                            .stroke(
                                                                Color(red: 0, green: 0, blue: 0).opacity(0.02), lineWidth: 0.25
                                                            )
                                                    )
                                                    .offset(x: -5.50, y: 0)
                                                    .shadow(
                                                        color: Color(red: 0, green: 0, blue: 0, opacity: 0.12), radius: 0.50, y: 0.25
                                                    )
                                            }
                                            .frame(width: 26, height: 15)
                                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.09))
                                            .cornerRadius(11)
                                        }
                                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                                        .background(Color(red: 1, green: 1, blue: 1).opacity(0.12))
                                        .cornerRadius(8)
                                        .blur(radius: 4)
                                        
                                        // Syntra row (highlighted)
                                        HStack(spacing: 59) {
                                            HStack(spacing: 4) {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 18, height: 18)
                                                    .background(Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.50))
                                                    .cornerRadius(4.50)
                                                Text("Syntra")
                                                    .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                                    .lineSpacing(16)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            ZStack() {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 13, height: 13)
                                                    .background(.white)
                                                    .cornerRadius(100)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 100)
                                                            .inset(by: -0.25)
                                                            .stroke(
                                                                Color(red: 0, green: 0, blue: 0).opacity(0.02), lineWidth: 0.25
                                                            )
                                                    )
                                                    .offset(x: -5.50, y: 0)
                                                    .shadow(
                                                        color: Color(red: 0, green: 0, blue: 0, opacity: 0.12), radius: 0.50, y: 0.25
                                                    )
                                            }
                                            .frame(width: 26, height: 15)
                                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.09))
                                            .cornerRadius(11)
                                        }
                                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                                        .background(Color(red: 0, green: 0, blue: 0).opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .inset(by: 0.50)
                                                .stroke(Color(red: 1, green: 0.63, blue: 0.22), lineWidth: 0.50)
                                        )
                                        .shadow(
                                            color: Color(red: 1, green: 0.63, blue: 0.22, opacity: 0.20), radius: 32, y: 4
                                        )
                                        
                                        // ChatGPT row
                                        HStack(spacing: 59) {
                                            HStack(spacing: 4) {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 18, height: 18)
                                                    .background(.white)
                                                    .cornerRadius(4.50)
                                                Text("ChatGPT")
                                                    .font(Font.custom("SF Pro Display", size: 13))
                                                    .lineSpacing(16)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            ZStack() {
                                                Rectangle()
                                                    .foregroundColor(.clear)
                                                    .frame(width: 13, height: 13)
                                                    .background(.white)
                                                    .cornerRadius(100)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 100)
                                                            .inset(by: -0.25)
                                                            .stroke(
                                                                Color(red: 0, green: 0, blue: 0).opacity(0.02), lineWidth: 0.25
                                                            )
                                                    )
                                                    .offset(x: -5.50, y: 0)
                                                    .shadow(
                                                        color: Color(red: 0, green: 0, blue: 0, opacity: 0.12), radius: 0.50, y: 0.25
                                                    )
                                            }
                                            .frame(width: 26, height: 15)
                                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.09))
                                            .cornerRadius(11)
                                        }
                                        .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                                        .background(Color(red: 1, green: 1, blue: 1).opacity(0.12))
                                        .cornerRadius(8)
                                        .blur(radius: 4)
                                    }
                                    
                                    // Help text
                                    HStack(spacing: 10) {
                                        Text("When you tap \"Grant Access,\" you'll be guided to the right place to turn it on.")
                                            .font(Font.custom("SF Pro", size: 10).weight(.regular))
                                            .lineSpacing(13)
                                            .foregroundColor(Color(red: 0, green: 0, blue: 0).opacity(0.56))
                                    }
                                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                                }
                            }
                            .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.07))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)
                    
                        
                        // Buttons row - directly underneath small image
                        // Grant Access button
                        Button(action: onGrantAccess) {
                            HStack(alignment: .center, spacing: 2) {
                                Text("Grant Access")
                                    .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                    .foregroundColor(Color(red: 0.33, green: 0.2, blue: 0.04))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
                            .background(Color(red: 1, green: 0.83, blue: 0.64).opacity(0.75))
                            .cornerRadius(100)
                            .shadow(color: Color(red: 1, green: 0.59, blue: 0.24).opacity(0.25), radius: 12, x: 0, y: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 100)
                                    .inset(by: 0.5)
                                    .stroke(Color(red: 0.99, green: 0.63, blue: 0.22).opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)

                        if let manualContinueTitle, let onManualContinue {
                            Button(action: onManualContinue) {
                                Text(manualContinueTitle)
                                    .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                    .foregroundColor(.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                                    .background(Color.black.opacity(0.08))
                                    .cornerRadius(100)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .focusable(false)
                        }

                        if let restartTitle, let onRestart {
                            Button(action: onRestart) {
                                Text(restartTitle)
                                    .font(Font.custom("SF Pro Display", size: 12).weight(.medium))
                                    .foregroundColor(.black.opacity(0.52))
                                    .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .focusable(false)
                        }
                    }
                    
                    Spacer()
                    
                    // Next Step button positioned 20% from bottom, right-aligned
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onNextStep) {
                                HStack(alignment: .center, spacing: 2) {
                                    Text("Next Step")
                                        .font(Font.custom("SF Pro Display", size: 13))
                                        .foregroundColor(.black.opacity(isPermissionGranted ? 1.0 : 0.4))
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.black.opacity(isPermissionGranted ? 1.0 : 0.4))
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(red: 1, green: 0.58, blue: 0.22).opacity(isPermissionGranted ? 1.0 : 0.1))
                                .cornerRadius(100)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!isPermissionGranted)
                        }

                        Spacer().frame(height: geometry.size.height * 0.1)
                        
                    }
                }
                .frame(width: geometry.size.width * rightSideWidth, height: geometry.size.height)
                .padding(.leading, 23.82)
                .padding(.trailing, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionTemplateView(
        title: "To assist you contextually, \nSyntra needs \nscreen access.",
        subtitle: "So it can read your screen.",
        isPermissionGranted: false,
        onGrantAccess: {},
        onNeedHelp: {},
        onNextStep: {},
        image: "slack-ss"
    )
    .frame(width: 800, height: 500)
} 
