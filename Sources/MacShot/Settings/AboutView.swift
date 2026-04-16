import SwiftUI

struct AboutView: View {
    @State private var showUpdateAlert = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("MacShot")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A powerful screenshot tool for macOS")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Designed and developed with care.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("© 2024 MacShot. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                Link("Website", destination: URL(string: "https://macshot.app")!)
                    .font(.caption)

                Link("Support", destination: URL(string: "https://macshot.app/support")!)
                    .font(.caption)
            }

            Button("Check for Updates") {
                showUpdateAlert = true
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .alert("Check for Updates", isPresented: $showUpdateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You are running the latest version of MacShot.")
        }
    }
}
