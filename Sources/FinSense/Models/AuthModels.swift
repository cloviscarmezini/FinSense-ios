// Sources/FinSense/Models/AuthModels.swift
import Foundation

public struct LoginRequestDTO: Codable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct RegisterRequestDTO: Codable {
    public let email: String
    public let password: String
    public let fullName: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case fullName = "full_name"
    }

    public init(email: String, password: String, fullName: String) {
        self.email = email
        self.password = password
        self.fullName = fullName
    }
}

public struct UserSummaryDTO: Codable, Identifiable, Hashable {
    public let id: UUID
    public let email: String
    public let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
    }

    public init(id: UUID, email: String, fullName: String) {
        self.id = id
        self.email = email
        self.fullName = fullName
    }
}

public struct AuthResponseDTO: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let user: UserSummaryDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresIn: Int,
        user: UserSummaryDTO
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.user = user
    }
}
