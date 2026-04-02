import SwiftUI
import SwiftData

/// Admin flow: generate an invite link/QR for a specific baby.
/// Caregiver flow: redeem an invite code typed or scanned.
struct InviteView: View {

    let babyID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager

    @State private var mode: InviteMode = .generate
    @State private var selectedRole: CaregiverRole = .caregiver
    @State private var generatedInvite: CaregiverInvite? = nil
    @State private var redeemCode: String = ""
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showCopied = false

    enum InviteMode { case generate, redeem }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    Text("Invite Someone").tag(InviteMode.generate)
                    Text("Join a Family").tag(InviteMode.redeem)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                ScrollView {
                    switch mode {
                    case .generate: generateView
                    case .redeem:   redeemView
                    }
                }
            }
            .navigationTitle("Caregivers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Generate

    private var generateView: some View {
        VStack(spacing: 24) {
            // Role picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose access level")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach([CaregiverRole.caregiver, .viewer], id: \.self) { role in
                    RoleOptionRow(role: role, isSelected: selectedRole == role) {
                        selectedRole = role
                        generatedInvite = nil  // reset if role changes
                    }
                }
            }

            // Generate / show QR
            if let invite = generatedInvite, invite.isValid {
                inviteCard(invite)
            } else {
                Button {
                    generateInvite()
                } label: {
                    Label("Generate Invite Link", systemImage: "link.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }

    private func inviteCard(_ invite: CaregiverInvite) -> some View {
        VStack(spacing: 20) {
            // QR code
            QRCodeView(content: inviteDeepLink(invite.code))
                .frame(width: 200, height: 200)
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

            // Code display
            VStack(spacing: 6) {
                Text("Share this code")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formattedCode(invite.code))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(4)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = invite.code
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    Label(showCopied ? "Copied!" : "Copy Code", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                ShareLink(item: inviteDeepLink(invite.code), message: Text("Join me on Baby Tracker!")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            // Expiry note
            Text("Expires in 7 days · \(invite.role.displayName) access")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Regenerate
            Button("Generate new code") {
                generatedInvite = nil
                generateInvite()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Redeem

    private var redeemView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter Invite Code")
                    .font(.title2.bold())
                Text("Ask the admin of the family to generate a code in their app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Code input
            TextField("XXXX-XXXX", text: $redeemCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(4)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: redeemCode) {
                    redeemCode = String(redeemCode.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                redeemInvite()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Family")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(redeemCode.count == 8 ? Color.accentColor : Color(.systemFill))
                )
            }
            .buttonStyle(.plain)
            .disabled(redeemCode.count < 8 || isLoading)
        }
        .padding(24)
    }

    // MARK: - Actions

    private func generateInvite() {
        let invite = CaregiverInvite(babyID: babyID, createdByID: UUID(), role: selectedRole)
        modelContext.insert(invite)
        try? modelContext.save()
        generatedInvite = invite

        syncManager.enqueue(SyncOperation(
            modelType: "CaregiverInvite",
            modelID: invite.id,
            operation: .insert,
            payload: Data()
        ))
    }

    private func redeemInvite() {
        isLoading = true
        error = nil
        // Validate against local invites first (for offline / same-device testing)
        let descriptor = FetchDescriptor<CaregiverInvite>(
            predicate: #Predicate { $0.code == redeemCode }
        )
        if let invite = (try? modelContext.fetch(descriptor))?.first {
            if !invite.isValid {
                error = invite.isExpired ? "This invite has expired." : "This invite has already been used."
                isLoading = false
                return
            }
            // Mark used
            invite.usedAt = Date()
            try? modelContext.save()
            dismiss()
        } else {
            // Fall through to Supabase lookup (stub — requires network)
            error = "Code not found. Check the code and try again."
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func inviteDeepLink(_ code: String) -> String {
        "babytracker://invite/\(code)"
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count == 8 else { return code }
        return "\(code.prefix(4))-\(code.suffix(4))"
    }
}

// MARK: - Role option row

private struct RoleOptionRow: View {
    let role: CaregiverRole
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QR Code View

/// Generates a QR code image using CoreImage — no third-party dependency.
struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQR() {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private func generateQR() -> UIImage? {
        guard let data = content.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }

        let scale: CGFloat = 10
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
