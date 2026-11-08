// Sources/FinSense/Views/Settings/AuthSheetView.swift
import SwiftUI

public struct AuthSheetView: View {
    @ObservedObject var authService: AuthService
    public var baseURL: String
    public var onSuccess: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    @State private var isRegisterMode: Bool = false
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    public init(
        authService: AuthService,
        baseURL: String,
        onSuccess: (() -> Void)? = nil
    ) {
        self.authService = authService
        self.baseURL = baseURL
        self.onSuccess = onSuccess
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Ação", selection: $isRegisterMode) {
                        Text("Entrar").tag(false)
                        Text("Criar Conta").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section(isRegisterMode ? "Criar Nova Conta" : "Acessar Conta Existente") {
                    if isRegisterMode {
                        TextField("Nome Completo", text: $fullName)
                            .textContentType(.name)
                    }

                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)

                    SecureField("Senha", text: $password)
                        .textContentType(isRegisterMode ? .newPassword : .password)
                }

                if let error = authService.errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(hex: "#EF4444"))
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#EF4444"))
                        }
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text(isRegisterMode ? "Cadastrar e Entrar" : "Entrar")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "#0284C7"))
                    .disabled(isSubmitDisabled)
                }
            }
            .navigationTitle(isRegisterMode ? "Cadastrar" : "Autenticação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var isSubmitDisabled: Bool {
        if authService.isLoading { return true }
        if email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty { return true }
        if isRegisterMode && fullName.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return false
    }

    private func submit() {
        Task {
            let success: Bool
            if isRegisterMode {
                success = await authService.register(
                    fullName: fullName,
                    email: email,
                    password: password,
                    baseURL: baseURL
                )
            } else {
                success = await authService.login(
                    email: email,
                    password: password,
                    baseURL: baseURL
                )
            }

            if success {
                onSuccess?()
                dismiss()
            }
        }
    }
}
