import SwiftUI

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    let duration: Double
    let shimmerColor: Color
    let backgroundColor: Color
    let intensity: CGFloat
    
    init(
        duration: Double = 1.5,
        shimmerColor: Color = .white,
        backgroundColor: Color = .gray.opacity(0.3),
        intensity: CGFloat = 0.7
    ) {
        self.duration = duration
        self.shimmerColor = shimmerColor
        self.backgroundColor = backgroundColor
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        // shimmer effect only (no background color)
                        shimmerColor
                            .opacity(intensity)
                            .mask(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .clear, location: 0),
                                                .init(color: .white.opacity(0.2), location: 0.3),
                                                .init(color: .white, location: 0.5),
                                                .init(color: .white.opacity(0.2), location: 0.7),
                                                .init(color: .clear, location: 1)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: isAnimating
                                            ? geometry.size.width
                                            : -geometry.size.width)
                                    .frame(width: geometry.size.width)
                            )
                    }
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// Extension for easy usage
extension View {
    func shimmer(
        duration: Double = 1.5,
        shimmerColor: Color = .white,
        backgroundColor: Color = .gray.opacity(0.3),
        intensity: CGFloat = 0.7
    ) -> some View {
        modifier(
            ShimmerEffect(
                duration: duration,
                shimmerColor: shimmerColor,
                backgroundColor: backgroundColor,
                intensity: intensity
            )
        )
    }
}

struct ShimmerTextView: View {
    let text: String
    let font: Font
    let textColor: Color
    let duration: Double
    let shimmerColor: Color
    let intensity: CGFloat
    
    init(
        text: String,
        font: Font = .title,
        textColor: Color = .white,
        duration: Double = 1.5,
        shimmerColor: Color = .white,
        intensity: CGFloat = 0.7
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.duration = duration
        self.shimmerColor = shimmerColor
        self.intensity = intensity
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
            .shimmer(
                duration: duration,
                shimmerColor: shimmerColor,
                backgroundColor: .clear, // set background to transparent
                intensity: intensity
            )
    }
}

#Preview {
    VStack(spacing: 30) {
        // Basic shimmer text
        ShimmerTextView(
            text: "Loading...",
            font: .system(size: 36),
            textColor: Color(white: 0),
            intensity: 0.8
        )
        
        // Custom color shimmer text
        ShimmerTextView(
            text: "Shimmer Effect",
            font: .system(size: 32, weight: .heavy),
            textColor: Color.purple.opacity(0.5),
            duration: 2.0,
            shimmerColor: Color.yellow,
            intensity: 0.9
        )
        
        // Shimmer effect can also be applied to regular Views
        RoundedRectangle(cornerRadius: 20)
            .frame(width: 300, height: 60)
            .shimmer(
                duration: 1.2,
                shimmerColor: .white,
                backgroundColor: .green.opacity(0.3),
                intensity: 0.8
            )
        
        // Text effect (glossy)
        Text("Sparkling Text")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.clear)
            .shimmer(
                duration: 2.5,
                shimmerColor: .white,
                backgroundColor: .orange,
                intensity: 1.0
            )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
