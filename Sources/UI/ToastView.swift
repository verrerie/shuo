import SwiftUI

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
    }
}
