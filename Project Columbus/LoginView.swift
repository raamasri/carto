import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("Log In to Cart-o")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                TextField("Username", text: $username)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)

                Button("Log In") {
                    authManager.logIn(username: username, password: password)
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .padding()
        }
    }
}
