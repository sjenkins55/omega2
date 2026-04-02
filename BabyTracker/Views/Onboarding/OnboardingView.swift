import SwiftUI
import SwiftData
import PhotosUI

/// Multi-step onboarding wizard.
/// On completion it writes a Baby + Caregiver to SwiftData and
/// sets hasCompletedOnboarding = true.
struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var auth

    @State private var step: OnboardingStep = .welcome

    // Baby fields
    @State private var babyName: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var babySex: BabySex = .unspecified
    @State private var babyPhoto: PhotosPickerItem? = nil
    @State private var babyPhotoData: Data? = nil
    @State private var isDueDate: Bool = false   // true if premature / not born yet

    // Caregiver fields
    @State private var caregiverName: String = ""

    // Permissions
    @State private var notificationsGranted: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                if step != .welcome {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                // Step content
                Group {
                    switch step {
                    case .welcome:    WelcomeStep(onNext: { step = .babySetup })
                    case .babySetup:  BabySetupStep(
                                        name: $babyName, dob: $dateOfBirth,
                                        sex: $babySex, photoItem: $babyPhoto,
                                        photoData: $babyPhotoData, isDueDate: $isDueDate,
                                        onBack: { step = .welcome },
                                        onNext: { step = .caregiverSetup }
                                      )
                    case .caregiverSetup: CaregiverSetupStep(
                                        name: $caregiverName,
                                        onBack: { step = .babySetup },
                                        onNext: { step = .permissions }
                                      )
                    case .permissions: PermissionsStep(
                                        notificationsGranted: $notificationsGranted,
                                        onFinish: { finish() }
                                      )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.progressSteps, id: \.self) { s in
                Capsule()
                    .fill(s == step ? Color.accentColor : Color(.systemFill))
                    .frame(width: s == step ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Finish

    private func finish() {
        // Create baby
        let baby = Baby(name: babyName.isEmpty ? "Baby" : babyName,
                        dateOfBirth: dateOfBirth,
                        dueDate: isDueDate ? dateOfBirth : nil,
                        sex: babySex)
        baby.photoData = babyPhotoData

        // Create / update the caregiver (may already exist from resolveInitialAuthState)
        let caregiver: Caregiver
        if let existing = auth.currentCaregiver {
            existing.displayName = caregiverName.isEmpty ? "Parent" : caregiverName
            caregiver = existing
        } else {
            caregiver = Caregiver(displayName: caregiverName.isEmpty ? "Parent" : caregiverName,
                                  role: .admin, isCurrentDevice: true)
            modelContext.insert(caregiver)
        }

        modelContext.insert(baby)

        // Grant admin access
        let access = BabyAccess(babyID: baby.id, caregiverID: caregiver.id, role: .admin)
        modelContext.insert(access)

        try? modelContext.save()

        appState.activeBabyID = baby.id
        appState.hasCompletedOnboarding = true
    }
}

// MARK: - Step enum

enum OnboardingStep: CaseIterable {
    case welcome, babySetup, caregiverSetup, permissions

    static let progressSteps: [OnboardingStep] = [.babySetup, .caregiverSetup, .permissions]
}
