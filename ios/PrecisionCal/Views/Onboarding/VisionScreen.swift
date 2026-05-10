import SwiftUI

struct VisionScreen: View {
    let onContinue: () -> Void
    @State private var rayX: CGFloat = -1.2
    @State private var titleAppeared = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ScanningRay()
                    .frame(width: geo.size.width * 0.7, height: geo.size.height)
                    .offset(x: rayX * geo.size.width)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 24)
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .clipShape(.rect(cornerRadius: 48))
                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.25), radius: 24, x: 0, y: 12)
                    .opacity(titleAppeared ? 1 : 0)
                    .scaleEffect(titleAppeared ? 1 : 0.92)
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        Text("PRECISIONCAL")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .tracking(4)
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }

                    Text("A warm sanctuary\nfor your body.")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 18)

                    Text("Personalized nutrition,\nhonest and human.")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .lineSpacing(4)
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 18)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

                PearlescentButton(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("Begin")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                rayX = 1.2
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.3)) {
                titleAppeared = true
            }
        }
    }
}

private struct ScanningRay: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: PrecisionCalTheme.terracotta.opacity(0.0), location: 0.35),
                .init(color: PrecisionCalTheme.terracotta.opacity(0.35), location: 0.5),
                .init(color: PrecisionCalTheme.terracotta.opacity(0.0), location: 0.65),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .blur(radius: 22)
    }
}
