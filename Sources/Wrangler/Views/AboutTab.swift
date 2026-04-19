// Sources/Wrangler/Views/AboutTab.swift
//
// About tab showing app name, version, build number,
// and credits. Centered layout with modern macOS styling.

import SwiftUI

struct AboutTab: View {

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // App icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                // App name + version
                VStack(spacing: 4) {
                    Text("Wrangler")
                        .font(.system(size: 26, weight: .bold))

                    Text("Version \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // Tagline
                Text("Wrangle your windows.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Links
            VStack(spacing: 8) {
                Link("GitHub", destination: URL(string: "https://github.com/jgaddis99/wrangler")!)
                    .font(.system(size: 11))
                Link("Support Development", destination: URL(string: "https://paypal.me/jgaddis99")!)
                    .font(.system(size: 11))
            }
            .padding(.bottom, 8)

            // Credits
            Text("by Jason Gaddis")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
