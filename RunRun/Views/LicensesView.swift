import SwiftUI

struct LicenseItem: Identifiable {
    let id = UUID()
    let title: String
    let licenseText: String
}

struct LicensesView: View {
    @State private var licenses: [LicenseItem] = []

    var body: some View {
        List(licenses) { license in
            NavigationLink(license.title) {
                LicenseDetailView(title: license.title, text: license.licenseText)
            }
        }
        .navigationTitle("Licenses")
        .analyticsScreen("Licenses")
        .task {
            loadLicenses()
        }
    }

    private func loadLicenses() {
        guard let settingsBundlePath = Bundle.main.path(forResource: "Settings", ofType: "bundle"),
              let settingsBundle = Bundle(path: settingsBundlePath),
              let plistPath = settingsBundle.path(forResource: "com.mono0926.LicensePlist", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let specifiers = plist["PreferenceSpecifiers"] as? [[String: Any]] else {
            return
        }

        var items: [LicenseItem] = []

        for specifier in specifiers {
            guard let type = specifier["Type"] as? String,
                  type == "PSChildPaneSpecifier",
                  let title = specifier["Title"] as? String,
                  let file = specifier["File"] as? String else {
                continue
            }

            if let licensePath = settingsBundle.path(forResource: file, ofType: "plist"),
               let licenseData = FileManager.default.contents(atPath: licensePath),
               let licensePlist = try? PropertyListSerialization.propertyList(from: licenseData, format: nil) as? [String: Any],
               let licenseSpecifiers = licensePlist["PreferenceSpecifiers"] as? [[String: Any]],
               let firstSpec = licenseSpecifiers.first,
               let footerText = firstSpec["FooterText"] as? String {
                items.append(LicenseItem(title: title, licenseText: footerText))
            }
        }

        licenses = items
    }
}

struct LicenseDetailView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LicensesView()
    }
}
