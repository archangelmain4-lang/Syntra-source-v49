//
//  WelcomeView.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI
import Lottie

struct WelcomeView: View {
    @State private var animationFinished = false
    @State private var showText = false
    @State private var showSecondText = false
    @State private var autoAdvanceTimer: Timer?
    @State private var finalAdvanceTimer: Timer?
    
    // Check if user has seen welcome before
    @AppStorage("HasSeenWelcome") private var hasSeenWelcome: Bool = false
    
    var onNext: () -> Void

    // TODO: change to 6.0 and 15.0
    var firstStateChangeTime = 2.0 // seconds
    var finalStateChangeTime = 2.0 // seconds

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                // Full screen Lottie Animation that extends beyond window bounds
                LottieView(animation: .named("welcome_animation"))
                    .playing(loopMode: .playOnce)
                    .animationDidFinish { completed in
                        if completed {
                            withAnimation(.easeInOut(duration: 0)) {
                                animationFinished = true
                                showText = true
                            }
                            
                            // Skip delays if user has seen welcome before
                            if hasSeenWelcome {
                                // Show both texts immediately and advance quickly
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSecondText = true
                                }
                                // Quick advance for returning users
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    onNext()
                                }
                            } else {
                                // Original timing for first-time users
                                // Start timer for transitioning to second text
                                autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: firstStateChangeTime, repeats: false) { _ in
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        showText = false
                                    }
                                    
                                    // After first text fades out, show second text
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation(.easeInOut(duration: 1.0)) {
                                            showSecondText = true
                                        }
                                    }
                                }
                                
                                // Start 15-second timer to automatically advance to next screen
                                finalAdvanceTimer = Timer.scheduledTimer(withTimeInterval: finalStateChangeTime, repeats: false) { _ in
                                    hasSeenWelcome = true // Mark as seen
                                    onNext()
                                }
                            }
                        }
                    }
                    // Total height: window height + top extension + bottom extension
                    .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 2)
                    .offset(x: -(proxy.size.width * 0.25), y: -(proxy.size.height * 0.5))
                    .ignoresSafeArea()
                    .opacity(1.0)
                
                // Debug overlay to visualize the positioning (remove in production)
                #if DEBUG
                // This shows the actual window bounds for reference
                Rectangle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                #endif
            }
            
            // First welcome text
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 20) {
                    VStack(spacing: 0) {
                        Text("Broaden your")
                            .font(
                                Font.custom("Syncopate", size: 13)
                                    .weight(.bold)
                            )
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .opacity(showText ? 1.0 : 0.0)
                        
                        Text("Syntra")
                            .font(
                                Font.custom("Syncopate", size: 56)
                                    .weight(.bold)
                            )
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .frame(width: 341, alignment: .center)
                            .opacity(showText ? 1.0 : 0.0)
                    }
                    
                }
                .animation(.easeInOut(duration: 0.8).delay(0.2), value: showText)
                
                Spacer()
            }
            
            // Second welcome text
            VStack {
                Spacer()
                
                Text("Syntra floats over every app, reads your screen,\n& helps instantly—no context switch required.")
                    .font(.system(size: 18, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .opacity(showSecondText ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 1.0), value: showSecondText)
                
                Spacer()
            }
        }
        .onAppear {
            // For returning users, skip the animation entirely and show content immediately
            if hasSeenWelcome {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationFinished = true
                    showText = true
                    showSecondText = true
                }
                // Very quick advance for returning users
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onNext()
                }
            }
        }
        .onDisappear {
            // Clean up timers when view disappears
            autoAdvanceTimer?.invalidate()
            finalAdvanceTimer?.invalidate()
        }
    }
}

#Preview {
    WelcomeView {
        print("Next tapped")
    }
    .frame(width: 600, height: 400)
    .background(.ultraThinMaterial)
    .colorScheme(.dark)
} 