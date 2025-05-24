import SwiftUI

struct SentenceView: View {
    let sentence: String
    
    var body: some View {
        Text(sentence)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.8))
            .cornerRadius(10)
            .padding()
    }
} 