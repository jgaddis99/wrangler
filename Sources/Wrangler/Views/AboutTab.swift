// Sources/Wrangler/Views/AboutTab.swift
//
// About tab showing app name, version, build number,
// and credits. Styled to match the modern card-based
// settings layout.

import SwiftUI

struct AboutTab: View {

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // App name
            Text("Wrangler")
                .font(.system(size: 28, weight: .bold))

            // Version
            Text("Version \(version) (\(build))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            // Tagline
            Text("Wrangle your windows.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .padding(.top, -8)

            Spacer()

            // Credits
            VStack(spacing: 6) {
                Text("by Jason Gaddis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
