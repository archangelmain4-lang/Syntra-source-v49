import SwiftUI

/// A ScrollView that fades out its content at the top and bottom edges.
struct FadingScrollView<Content: View>: View {
    let fadeHeight: CGFloat = 32
    let content: () -> Content

    var body: some View {
        ScrollView {
            content()
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)

                Rectangle()
                    .frame(maxHeight: .infinity)

                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
            }
        )
    }
}

#Preview {
    FadingScrollView {
        VStack(spacing: 16) {
            ForEach(0..<50) { i in
                Text("Item \(i)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.black))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal).padding(.vertical, 50)
    }
}
