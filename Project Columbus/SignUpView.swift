import SwiftUI
import AuthenticationServices

struct UserInsert: Codable {
    let id: String
    let username: String
    let email: String
    let phone: String
    let full_name: String
}

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @FocusState private var usernameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @FocusState private var phoneFocused: Bool
    @FocusState private var fullNameFocused: Bool

    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var fadeOut = false
    @State private var currentNonce: String?
    @State private var signUpError: String?
    @State private var showErrorAlert = false
    @State private var showUsernamePrompt = false
    @State private var isCheckingUsername = false
    @State private var usernameError: String? = nil

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
                TextField("Full Name", text: $fullName)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($fullNameFocused)
                    .submitLabel(.next)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .onSubmit {
                        usernameFocused = true
                    }
                    .onTapGesture {
                        fullNameFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !fullName.isEmpty {
                                Button(action: { fullName = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                TextField("Desired Username (@urmom)", text: $username)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($usernameFocused)
                    .submitLabel(.next)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .keyboardType(.default)
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
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
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
                    .onChange(of: phone) { _, newValue in
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
                    .textContentType(.newPassword)
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
                    if !fullName.isEmpty && !username.isEmpty && !email.isEmpty && !phone.isEmpty && !password.isEmpty {
                        isCheckingUsername = true
                        usernameError = nil
                        Task {
                            let available = await SupabaseManager.shared.isUsernameAvailable(username: username)
                            isCheckingUsername = false
                            if !available {
                                usernameError = "Username is already taken."
                                showErrorAlert = true
                                return
                            }
                            do {
                                try await authManager.signUp(email: email, password: password, username: username, fullName: fullName, phone: phone)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    fadeOut = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } catch {
                                if (error as NSError).code == 409 {
                                    signUpError = "An account with this email already exists."
                                } else {
                                    signUpError = error.localizedDescription
                                }
                                showErrorAlert = true
                                print("Sign up failed: \(error)")
                            }
                        }
                    }
                }) {
                    if isCheckingUsername {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign Up")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .bold()
                    }
                }
                .alert(isPresented: $showErrorAlert) {
                    Alert(
                        title: Text("Sign Up Failed"),
                        message: Text(usernameError ?? signUpError ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
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
        .onReceive(NotificationCenter.default.publisher(for: .showUsernamePrompt)) { _ in
            showUsernamePrompt = true
        }
        .sheet(isPresented: $showUsernamePrompt) {
            UsernamePromptView { chosenUsername in
                Task {
                    if let user = try? await SupabaseManager.shared.client.auth.user() {
                        _ = try? await SupabaseManager.shared.client
                            .from("users")
                            .update(["username": chosenUsername])
                            .eq("id", value: user.id.uuidString)
                            .execute()
                    }
                }
                showUsernamePrompt = false
            }
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
