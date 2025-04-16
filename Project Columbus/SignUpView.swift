import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @FocusState private var usernameFocused: Bool
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showBuildProfile = false
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false

    var body: some View {
        ZStack {
            Color.clear
                .background(.thinMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("Join CARTO")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                TextField("Username", text: $username)
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

                TextField("Email", text: $email)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .focused($emailFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        passwordFocused = true
                    }
                    .onTapGesture {
                        emailFocused = true
                    }

                SecureField("Password", text: $password)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .focused($passwordFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if !username.isEmpty && !email.isEmpty && !password.isEmpty {
                            showBuildProfile = true
                        }
                    }
                    .onTapGesture {
                        passwordFocused = true
                    }

                Button("Choose Profile Image") {
                    showImagePicker = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)

                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(Circle())
                }

                Button("Sign Up") {
                    if !username.isEmpty && !email.isEmpty && !password.isEmpty {
                        showBuildProfile = true
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .sheet(isPresented: $showBuildProfile) {
                    BuildProfileView()
                        .environmentObject(authManager)
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            // Handle successful authorization
                            print("Apple Sign In successful: \(authorization)")
                        case .failure(let error):
                            // Handle error
                            print("Apple Sign In failed: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 45)
                .cornerRadius(10)
            }
            .padding()
            .opacity(0.95)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
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
