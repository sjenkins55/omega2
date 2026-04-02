import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Hero
                VStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    Text("Sync Your Data")
                        .font(.title.bold())
                    Text("Sign in to sync across devices and share with your partner or other caregivers. Your data is private and encrypted.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Benefits list
                VStack(alignment: .leading, spacing: 14) {
                    benefitRow(icon: "iphone.and.arrow.forward", color: .blue,
                               text: "Access from all your Apple devices")
                    benefitRow(icon: "person.2.fill", color: .purple,
                               text: "Share with your partner and caregivers")
                    benefitRow(icon: "arrow.triangle.2.circlepath", color: .green,
                               text: "Automatic background sync")
                    benefitRow(icon: "lock.shield.fill", color: .orange,
                               text: "Your data stays private — never sold")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Error
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Sign in button
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = auth.prepareNonce()
                    } onCompletion: { result in
                        isLoading = true
                        Task {
                            await auth.handleAppleSignIn(result: result)
                            await MainActor.run {
                                isLoading = false
                                if auth.isAuthenticated { dismiss() }
                                else { self.error = "Sign in failed. Please try again." }
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .disabled(isLoading)

                    Button("Continue without signing in") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .presentationDetents([.large])
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 20))
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
        }
    }
}
