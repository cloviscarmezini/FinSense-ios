// Sources/FinSense/Views/Settings/RemoteAIManagementView.swift
import SwiftUI

public struct RemoteAIManagementView: View {
    @ObservedObject var aiService: CloudAIService
    @ObservedObject var syncService: CloudSyncService

    public init(aiService: CloudAIService, syncService: CloudSyncService) {
        self.aiService = aiService
        self.syncService = syncService
    }

    public var body: some View {
        ModelSelectorSheet(aiService: aiService, baseURL: syncService.baseURLString)
    }
}
