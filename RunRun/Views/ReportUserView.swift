import SwiftUI

/// ユーザー通報フォーム（プロフィール画面のメニューから表示）
struct ReportUserView: View {
    @Environment(\.dismiss) private var dismiss
    let reporterId: String
    let reportedUser: UserProfile
    let onSubmitted: () -> Void

    @State private var selectedReason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let maxLength = FirestoreService.reportDetailsMaxLength

    private var detailsLength: Int {
        details.unicodeScalars.count
    }

    private var canSubmit: Bool {
        selectedReason != nil && !isSubmitting && detailsLength <= maxLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ProfileAvatarView(user: reportedUser, size: 40)
                        Text(reportedUser.displayName)
                            .font(.headline)
                    }
                }

                Section("Reason") {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "\(detailsLength)/\(maxLength)")
                            .foregroundStyle(detailsLength > maxLength ? .red : .secondary)
                        Text("Reports are reviewed by the RunRun team. The reported user won't be notified.")
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .analyticsScreen("ReportUser")
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            Task { await submit() }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func submit() async {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await firestoreService.reportUser(
                reporterId: reporterId,
                reportedUser: reportedUser,
                reason: reason,
                details: details
            )
            AnalyticsService.logEvent("report_user", parameters: ["reason": reason.rawValue])
            dismiss()
            onSubmitted()
        } catch {
            print("Report user error: \(error)")
            errorMessage = String(localized: "Couldn't submit the report. Please try again.")
        }

        isSubmitting = false
    }
}

#Preview {
    ReportUserView(
        reporterId: "me",
        reportedUser: UserProfile(id: "other", displayName: "Runner", email: nil, iconName: "figure.run", avatarURL: nil, createdAt: Date()),
        onSubmitted: {}
    )
}
