import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

struct LoginView: View {
    @State private var currentNonce: String?

    var body: some View {
        VStack {
            Text("Welcome to Santé")
                .font(.title)
                .padding()

            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleSignIn(result)
            }
            .frame(height: 50)
            .padding()
        }
    }

    func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let nonce = currentNonce else {
                print("Missing nonce — cannot proceed with login")
                return
            }
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let tokenData = credential.identityToken,
               let idTokenString = String(data: tokenData, encoding: .utf8) {

                let firebaseCredential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: idTokenString,
                    rawNonce: nonce
                )

                Auth.auth().signIn(with: firebaseCredential) { authResult, error in
                    if let error = error {
                        print("Something went wrong: \(error.localizedDescription)")
                        return
                    }
                    print("Logged in! Your user ID is: \(authResult?.user.uid ?? "unknown")")
                }
            }
        case .failure(let error):
            print("Login was cancelled or failed: \(error.localizedDescription)")
        }
    }

    // Generates a random string to use as our nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    // Hashes the nonce before sending it to Apple (Apple requires this)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
