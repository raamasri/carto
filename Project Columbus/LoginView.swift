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
                Text("Log In to CARTO")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                TextField("Username", text: $username)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    // Ensure the entire background rectangle is tappable
                    .contentShape(Rectangle())

                SecureField("Password", text: $password)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    // Ensure the entire background rectangle is tappable
                    .contentShape(Rectangle())
                
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
