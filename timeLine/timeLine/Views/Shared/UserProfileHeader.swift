import SwiftUI

struct UserProfileHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            // Avatar Placeholder
            ZStack {
                Circle()
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .foregroundColor(Color(UIColor.systemGray4))
                
                // Level Badge
                VStack {
                    Spacer()
                    Text("Lvl 12")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(8)
                        .offset(y: 6)
                }
            }
            .frame(width: 60, height: 66) // Slightly taller for badge offset
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Wanderer Alex")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 0) {
                    Text("Free Account • ")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Upgrade to Pro")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    UserProfileHeader()
        .preferredColorScheme(.dark)
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
}
