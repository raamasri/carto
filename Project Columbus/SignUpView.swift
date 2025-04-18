import SwiftUI
import AuthenticationServices

struct UserInsert: Codable {
    let id: String
    let username: String
    let email: String
    let phone: String
}

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @FocusState private var usernameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @FocusState private var phoneFocused: Bool

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var fadeOut = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            Color.clear
                .background(.thinMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                HStack {
                    Text("Welcome, Cartographer")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                }

                TextField("Desired Username (@urmom)", text: $username)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($usernameFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        emailFocused = true
                    }
                    .onTapGesture {
                        usernameFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !username.isEmpty {
                                Button(action: { username = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                TextField("Email", text: $email)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($emailFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        phoneFocused = true
                    }
                    .onTapGesture {
                        emailFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !email.isEmpty {
                                Button(action: { email = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                TextField("Phone Number", text: Binding(
                    get: { phone },
                    set: { phone = formatPhoneNumber($0) }
                ))
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($phoneFocused)
                    .submitLabel(.next)
                    .keyboardType(.phonePad)
                    .onSubmit {
                        passwordFocused = true
                    }
                    .onTapGesture {
                        phoneFocused = true
                    }
                    .onChange(of: phone) { newValue in
                        phone = formatPhoneNumber(newValue)
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !phone.isEmpty {
                                Button(action: { phone = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                SecureField("Password", text: $password)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .focused($passwordFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if !username.isEmpty && !email.isEmpty && !phone.isEmpty && !password.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                fadeOut = true
                            }
                        }
                    }
                    .onTapGesture {
                        passwordFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !password.isEmpty {
                                Button(action: { password = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                Button(action: {
                    showImagePicker = true
                }) {
                    Text("Choose Profile Image")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .bold()
                }

                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(Circle())
                }

                Button(action: {
                    if !username.isEmpty && !email.isEmpty && !phone.isEmpty && !password.isEmpty {
                        Task {
                            do {
                                try await AuthService.shared.signUp(email: email, password: password)
                                
                                if let userId = SupabaseManager.shared.client.auth.currentUser?.id {
                                    let insertData = UserInsert(id: userId.uuidString, username: username, email: email, phone: phone)
                                    _ = try await SupabaseManager.shared.client
                                        .from("users")
                                        .insert(insertData)
                                        .execute()
                                }
                                
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    fadeOut = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } catch {
                                print("Sign up failed: \(error)")
                            }
                        }
                    }
                }) {
                    Text("Sign Up")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .bold()
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = SupabaseManager.shared.generateNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = SupabaseManager.shared.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard
                                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                let tokenData = appleIDCredential.identityToken,
                                let idToken = String(data: tokenData, encoding: .utf8),
                                let nonce = currentNonce
                            else {
                                print("❌ Failed to get Apple identityToken or nonce")
                                return
                            }

                            Task {
                                do {
                                    let session = try await SupabaseManager.shared.signInWithApple(idToken: idToken, nonce: nonce)
                                    print("✅ Supabase Apple Sign-In success: \(session)")
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        fadeOut = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                } catch {
                                    print("❌ Supabase Apple Sign-In failed:", error)
                                }
                            }

                        case .failure(let error):
                            print("❌ Apple Sign In failed:", error.localizedDescription)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 45)
                .cornerRadius(10)
            }
            .padding()
            .opacity(fadeOut ? 0 : 1)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isWholeNumber }
        let capped = String(digits.prefix(10))

        if capped.count <= 3 {
            return capped
        } else if capped.count <= 6 {
            let area = capped.prefix(3)
            let prefix = capped.dropFirst(3)
            return "(\(area)) \(prefix)"
        } else {
            let area = capped.prefix(3)
            let prefix = capped.dropFirst(3).prefix(3)
            let line = capped.dropFirst(6)
            return "(\(area)) \(prefix)-\(line)"
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
