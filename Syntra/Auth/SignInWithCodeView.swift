//
//  SignInWithCodeView.swift
//  Syntra
//
//  Lets the user sign in to Syntra Opus by typing the 8-digit pairing code
//  shown on https://syntra.cc/desktop-auth in their browser.
//

import SwiftUI
import AppKit

struct SignInWithCodeView: View {
    @State private var code: String = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    var onSignedIn: (() -> Void)? = nil

    private var formatted: String {
        let digits = code.filter(\.isNumber)
        if digits.count <= 4 { return digits }
        let head = digits.prefix(4)
        let tail = digits.dropFirst(4).prefix(4)
        return "\(head) \(tail)"
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Sign in to Syntra Opus")
                .font(.system(size: 20, weight: .semibold))

            Text("Open syntra.cc/desktop-auth in your browser, then type the 8-digit code shown there.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            TextField("0000 0000", text: Binding(
                get: { formatted },
                set: { newValue in
                    code = String(newValue.filter(\.isNumber).prefix(8))
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: 220)
            .disabled(isVerifying)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: submit) {
                if isVerifying {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Sign in").frame(maxWidth: 200)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(code.count != 8 || isVerifying)

            Button("Open syntra.cc/desktop-auth") {
                if let url = URL(string: "https://syntra.cc/desktop-auth") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
        .padding(28)
        .frame(width: 360)
    }

    private func submit() {
        guard code.count == 8 else { return }
        isVerifying = true
        errorMessage = nil
        AuthManager.shared.verifyPairingCode(code) { result in
            isVerifying = false
            switch result {
            case .success:
                onSignedIn?()
            case .failure(let err):
                errorMessage = err.errorDescription
            }
        }
    }
}

#Preview { SignInWithCodeView() }
