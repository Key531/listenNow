//
//  ContentView.swift
//  ListenNow
//
//  Created by 기성준 on 4/5/26.
//

import AVFAudio
import Foundation
import Speech
import SwiftUI
import Translation
import UIKit

// MARK: - Models

enum RecordingState {
    case idle
    case recording
    case paused
}

enum AppTypography {
    static func regular(_ size: CGFloat) -> Font {
        .custom("Helvetica", size: size)
    }

    static func bold(_ size: CGFloat) -> Font {
        .custom("Helvetica-Bold", size: size)
    }
}

enum CopySection {
    case original
    case translated

    var title: String {
        switch self {
        case .original:
            "Original"
        case .translated:
            "Translation"
        }
    }
}

enum TranslationSupportState: Equatable {
    case checking
    case installed
    case supported
    case unsupported

    var message: String? {
        switch self {
        case .checking:
            "Checking translation availability."
        case .installed:
            nil
        case .supported:
            "This language pair is supported. Translation resources may need to download the first time."
        case .unsupported:
            "This language pair is not currently available on this device."
        }
    }
}

enum TranslationEngine: String, CaseIterable, Identifiable {
    case apple = "Apple"
    case llm = "LLM"

    var id: String { rawValue }
}

enum SpeechEngine: String, CaseIterable, Identifiable {
    case apple = "Apple"
    case llm = "LLM"

    var id: String { rawValue }
}

enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"
    case custom = "Custom"

    var id: String { rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "EN"
    case korean = "KO"
    case japanese = "JA"
    case chinese = "ZH"
    case spanish = "ES"
    case french = "FR"
    case german = "DE"

    var id: String { rawValue }

    var speechLocaleIdentifier: String {
        switch self {
        case .english:
            "en-US"
        case .korean:
            "ko-KR"
        case .japanese:
            "ja-JP"
        case .chinese:
            "zh-CN"
        case .spanish:
            "es-ES"
        case .french:
            "fr-FR"
        case .german:
            "de-DE"
        }
    }

    var translationLanguage: Locale.Language {
        switch self {
        case .english:
            Locale.Language(identifier: "en")
        case .korean:
            Locale.Language(identifier: "ko")
        case .japanese:
            Locale.Language(identifier: "ja")
        case .chinese:
            Locale.Language(identifier: "zh")
        case .spanish:
            Locale.Language(identifier: "es")
        case .french:
            Locale.Language(identifier: "fr")
        case .german:
            Locale.Language(identifier: "de")
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("llm_api_key") private var llmApiKey: String = ""
    @AppStorage("llm_model") private var llmModel: String = "gpt-4.1-mini"
    @AppStorage("llm_provider") private var llmProviderRawValue: String = LLMProvider.openAI.rawValue
    @AppStorage("llm_correction_enabled") private var llmCorrectionEnabled: Bool = true
    @State private var recordingState: RecordingState = .idle
    @State private var sourceLanguage: AppLanguage = .english
    @State private var targetLanguage: AppLanguage = .korean
    @State private var originalText: String = ""
    @State private var translatedText: String = ""
    @State private var statusMessage: String = "Organize live conversations with clarity and calm."
    @State private var copiedSection: CopySection?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translationSourceText: String = ""
    @State private var recognizerAvailable: Bool = true
    @State private var speechEngine: SpeechEngine = .apple
    @State private var translationSupportState: TranslationSupportState = .checking
    @State private var translationEngine: TranslationEngine = .apple
    @State private var speechController = LiveSpeechRecognizer()
    @State private var llmRecorder = LLMRecorder()
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var translationDebounceTask: Task<Void, Never>?
    @State private var correctionDebounceTask: Task<Void, Never>?
    @State private var lastCorrectionSourceText: String = ""
    @State private var demoTask: Task<Void, Never>?
    @State private var demoTranscriptIndex: Int = 0
    @State private var availabilityTask: Task<Void, Never>?
    @State private var showingLLMSettings: Bool = false

    private let demoTranscript = [
        (
            original: "Thanks for joining today. I want to walk through the product direction.",
            translations: [
                AppLanguage.korean: "오늘 함께해줘서 고마워요. 제품 방향을 함께 살펴보고 싶습니다."
            ]
        ),
        (
            original: "The interface should feel quiet, fast, and easy to trust.",
            translations: [
                AppLanguage.korean: "인터페이스는 조용하고 빠르며 신뢰하기 쉬운 느낌이어야 합니다."
            ]
        ),
        (
            original: "We can start with a focused experience and expand carefully.",
            translations: [
                AppLanguage.korean: "우리는 집중된 경험으로 시작한 뒤 신중하게 확장할 수 있습니다."
            ]
        ),
        (
            original: "Let’s keep the details simple so the conversation stays natural.",
            translations: [
                AppLanguage.korean: "대화가 자연스럽게 이어지도록 세부 사항은 단순하게 유지합시다."
            ]
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 140, y: -250)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                contentLayout
                .padding(.horizontal, isPadLayout ? 20 : 18)
                .padding(.top, isPadLayout ? 28 : 18)
                .padding(.bottom, isPadLayout ? 32 : 20)
            }
        }
        .task {
            configureSpeechCallbacks()
            checkTranslationAvailability()
        }
        .onChange(of: sourceLanguage) { _, _ in
            languageDidChange()
        }
        .onChange(of: targetLanguage) { _, _ in
            checkTranslationAvailability()
            scheduleTranslation()
        }
        .onChange(of: translationEngine) { _, _ in
            checkTranslationAvailability()
            scheduleTranslation()
        }
        .onChange(of: speechEngine) { _, _ in
            if speechEngine == .llm, !isSimulatorEnvironment {
                statusMessage = "\(llmProvider.rawValue) LLM STT selected. Full integration is the next step."
            } else {
                updateStatusMessage()
            }
        }
        .translationTask(translationConfiguration) { session in
            guard translationEngine == .apple else { return }

            let sourceSnapshot = translationSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sourceSnapshot.isEmpty else { return }

            do {
                let response = try await session.translate(sourceSnapshot)

                await MainActor.run {
                    guard sourceSnapshot == translationSourceText else { return }
                    translatedText = response.targetText
                }
            } catch {
                await MainActor.run {
                    guard sourceSnapshot == translationSourceText else { return }
                    translatedText = ""
                    if recordingState == .recording || recordingState == .paused {
                        statusMessage = "Translation is not ready yet. Original text will continue to accumulate."
                    }
                }
            }
        }
        .sheet(isPresented: $showingLLMSettings) {
            EngineSettingsView(
                speechEngine: $speechEngine,
                translationEngine: $translationEngine,
                llmProvider: Binding(
                    get: { llmProvider },
                    set: { llmProviderRawValue = $0.rawValue }
                ),
                llmCorrectionEnabled: $llmCorrectionEnabled,
                apiKey: $llmApiKey,
                model: $llmModel
            )
        }
        .onDisappear {
            speechController.stopListening()
            _ = llmRecorder.stopRecording()
            copyFeedbackTask?.cancel()
            translationDebounceTask?.cancel()
            correctionDebounceTask?.cancel()
            demoTask?.cancel()
            availabilityTask?.cancel()
        }
    }

    private func configureSpeechCallbacks() {
        speechController.onTranscriptChange = { transcript in
            originalText = transcript
            scheduleCorrection(for: transcript)
            scheduleTranslation()
        }

        speechController.onAvailabilityChange = { available in
            recognizerAvailable = available
            if !available {
                statusMessage = "Speech recognition is not available for this language right now."
            } else {
                updateStatusMessage()
            }
        }

        speechController.onError = { message in
            statusMessage = message
            if recordingState == .recording {
                recordingState = .paused
            }
        }
    }

    private func startRecording() {
        Task {
            translatedText = ""
            originalText = ""
            copiedSection = nil
            translationConfiguration = nil
            translationSourceText = ""
            lastCorrectionSourceText = ""
            updateStatusMessage()

            if isSimulatorEnvironment {
                startDemoStream(resetTranscript: true)
                recordingState = .recording
                statusMessage = "Playing sample lines in Simulator demo mode."
                return
            }

            if speechEngine == .llm {
                let started = await startLLMRecording(resetTranscript: true)
                if started {
                    recordingState = .recording
                    statusMessage = "Recording with \(llmProvider.rawValue) LLM STT. The transcript will appear when you stop."
                }
                return
            }

            let started = await startRecognitionSession(resetTranscript: true)
            if started {
                recordingState = .recording
                updateStatusMessage()
            }
        }
    }

    private func pauseRecording() {
        if isSimulatorEnvironment {
            demoTask?.cancel()
            recordingState = .paused
            statusMessage = "Demo playback is paused."
            return
        }

        if speechEngine == .llm {
            llmRecorder.pauseRecording()
            recordingState = .paused
            statusMessage = "LLM STT recording is paused."
            return
        }

        speechController.pauseListening()
        recordingState = .paused
        updateStatusMessage()
    }

    private func resumeRecording() {
        if isSimulatorEnvironment {
            startDemoStream(resetTranscript: false)
            recordingState = .recording
            statusMessage = "Resuming demo playback."
            return
        }

        if speechEngine == .llm {
            do {
                try llmRecorder.resumeRecording()
                recordingState = .recording
                statusMessage = "Resuming \(llmProvider.rawValue) LLM STT recording."
            } catch {
                recordingState = .paused
                statusMessage = "Could not resume LLM STT recording."
            }
            return
        }

        Task {
            let started = await startRecognitionSession(resetTranscript: false)
            if started {
                recordingState = .recording
                updateStatusMessage()
            }
        }
    }

    private func stopRecording() {
        if isSimulatorEnvironment {
            demoTask?.cancel()
            demoTask = nil
            recordingState = .idle
            lastCorrectionSourceText = originalText
            updateStatusMessage()
            scheduleTranslation()
            return
        }

        if speechEngine == .llm {
            Task {
                await stopLLMRecordingAndTranscribe()
            }
            return
        }

        speechController.stopListening()
        recordingState = .idle
        lastCorrectionSourceText = originalText
        updateStatusMessage()
        scheduleTranslation()
    }

    private func startLLMRecording(resetTranscript: Bool) async -> Bool {
        if llmProvider != .openAI {
            statusMessage = "\(llmProvider.rawValue) LLM STT is not implemented yet."
            return false
        }

        let apiKey = llmApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            statusMessage = "Enter a \(llmProvider.rawValue) API key to use LLM STT."
            return false
        }

        do {
            if resetTranscript {
                originalText = ""
                translatedText = ""
            }

            let granted = await llmRecorder.requestMicrophonePermission()
            guard granted else {
                statusMessage = "Microphone access is required."
                return false
            }

            try llmRecorder.startRecording(resetFile: resetTranscript)
            return true
        } catch {
            statusMessage = "Could not start LLM STT recording."
            return false
        }
    }

    private func stopLLMRecordingAndTranscribe() async {
        let apiKey = llmApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            recordingState = .idle
            statusMessage = "Enter a \(llmProvider.rawValue) API key to use LLM STT."
            return
        }

        guard let audioURL = llmRecorder.stopRecording() else {
            recordingState = .idle
            statusMessage = "Could not prepare the recorded audio file."
            return
        }

        statusMessage = "Processing \(llmProvider.rawValue) LLM STT transcription."

        do {
            let transcript = try await LLMTranscriptionService.transcribe(
                fileURL: audioURL,
                language: sourceLanguage,
                apiKey: apiKey,
                provider: llmProvider
            )

            originalText = transcript
            recordingState = .idle
            updateStatusMessage()
            scheduleTranslation()
        } catch {
            originalText = ""
            recordingState = .idle
            statusMessage = "\(llmProvider.rawValue) STT transcription request failed."
        }
    }

    private func startRecognitionSession(resetTranscript: Bool) async -> Bool {
        do {
            if resetTranscript {
                speechController.resetTranscript()
            }

            let permissions = await speechController.requestPermissions()
            guard permissions else {
                recordingState = .idle
                statusMessage = "Microphone and speech recognition access are required."
                return false
            }

            try speechController.startListening(localeIdentifier: sourceLanguage.speechLocaleIdentifier)
            return true
        } catch {
            recordingState = .idle
            statusMessage = error.localizedDescription
            return false
        }
    }

    private func languageDidChange() {
        if recordingState == .recording {
            speechController.stopListening()
            recordingState = .paused
            statusMessage = "The input language changed. Tap Resume to restart with the new language."
        } else {
            updateStatusMessage()
        }

        checkTranslationAvailability()
        scheduleTranslation()
    }

    private func updateStatusMessage() {
        switch recordingState {
        case .idle:
            statusMessage = "Organize live conversations with clarity and calm."
        case .recording:
            statusMessage = "Original text and translation build up live while you speak."
        case .paused:
            statusMessage = "Paused for now. You can continue listening at any time."
        }
    }

    private func scheduleTranslation() {
        translationDebounceTask?.cancel()

        if isSimulatorEnvironment {
            translatedText = demoTranslationText()
            return
        }

        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            translationSourceText = ""
            translationConfiguration = nil
            return
        }

        guard sourceLanguage != targetLanguage else {
            translatedText = originalText
            translationSourceText = ""
            translationConfiguration = nil
            return
        }

        translationDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            if translationEngine == .apple {
                guard translationSupportState != .unsupported else {
                    await MainActor.run {
                        translatedText = ""
                        translationSourceText = ""
                        translationConfiguration = nil
                        if let message = translationSupportState.message {
                            statusMessage = message
                        }
                    }
                    return
                }

                await MainActor.run {
                    translationSourceText = originalText
                    translationConfiguration = .init(
                        source: sourceLanguage.translationLanguage,
                        target: targetLanguage.translationLanguage
                    )
                }
                return
            }

            let apiKey = llmApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                await MainActor.run {
                    translatedText = ""
                    statusMessage = "Enter a \(llmProvider.rawValue) API key to use LLM translation."
                }
                return
            }

            let sourceText = originalText
            let source = sourceLanguage
            let target = targetLanguage
            let model = llmModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : llmModel

            do {
                let translated = try await LLMTranslationService.translate(
                    text: sourceText,
                    sourceLanguage: source,
                    targetLanguage: target,
                    apiKey: apiKey,
                    model: model,
                    provider: llmProvider
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard sourceText == originalText else { return }
                    translatedText = translated
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard sourceText == originalText else { return }
                    translatedText = ""
                    statusMessage = "\(llmProvider.rawValue) translation failed. Check your API key and network connection."
                }
            }
        }
    }

    private func scheduleCorrection(for transcript: String) {
        correctionDebounceTask?.cancel()

        guard speechEngine == .apple else { return }
        guard llmCorrectionEnabled else { return }
        guard !isSimulatorEnvironment else { return }

        let apiKey = llmApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard shouldRunCorrection(for: trimmed) else { return }

        correctionDebounceTask = Task {
            let delay: Duration = looksLikeSentenceBoundary(in: trimmed) ? .milliseconds(250) : .milliseconds(900)
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            let sourceSnapshot = transcript
            let model = llmModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : llmModel

            do {
                let corrected = try await LLMTranslationService.correctTranscript(
                    text: sourceSnapshot,
                    language: sourceLanguage,
                    apiKey: apiKey,
                    model: model,
                    provider: llmProvider
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard originalText == sourceSnapshot else { return }
                    originalText = corrected
                    lastCorrectionSourceText = corrected
                    scheduleTranslation()
                }
            } catch {
                // Keep live Apple STT text if correction fails.
            }
        }
    }

    private func shouldRunCorrection(for transcript: String) -> Bool {
        guard transcript != lastCorrectionSourceText else { return false }

        let growth = transcript.count - lastCorrectionSourceText.count
        if looksLikeSentenceBoundary(in: transcript) {
            return growth >= 8
        }

        return growth >= 24
    }

    private func looksLikeSentenceBoundary(in transcript: String) -> Bool {
        guard let lastCharacter = transcript.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }

        return [".", "!", "?", "。", "！", "？"].contains(lastCharacter)
    }

    private func checkTranslationAvailability() {
        availabilityTask?.cancel()

        guard translationEngine == .apple else {
            translationSupportState = .installed
            return
        }

        guard !isSimulatorEnvironment else {
            translationSupportState = .installed
            return
        }

        guard sourceLanguage != targetLanguage else {
            translationSupportState = .installed
            return
        }

        translationSupportState = .checking

        let source = sourceLanguage.translationLanguage
        let target = targetLanguage.translationLanguage

        availabilityTask = Task {
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                switch status {
                case .installed:
                    translationSupportState = .installed
                case .supported:
                    translationSupportState = .supported
                case .unsupported:
                    translationSupportState = .unsupported
                @unknown default:
                    translationSupportState = .unsupported
                }

                if let message = translationSupportState.message,
                   recordingState != .recording {
                    statusMessage = message
                } else if translationSupportState == .installed {
                    updateStatusMessage()
                }
            }
        }
    }

    private func copyOriginalText() {
        UIPasteboard.general.string = originalText
        showCopyFeedback(for: .original)
    }

    private func copyTranslatedText() {
        UIPasteboard.general.string = translatedText
        showCopyFeedback(for: .translated)
    }

    private func showCopyFeedback(for section: CopySection) {
        copyFeedbackTask?.cancel()

        withAnimation(.easeOut(duration: 0.2)) {
            copiedSection = section
        }

        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    copiedSection = nil
                }
            }
        }
    }

    private func startDemoStream(resetTranscript: Bool) {
        demoTask?.cancel()

        if resetTranscript {
            demoTranscriptIndex = 0
            originalText = ""
            translatedText = ""
        }

        demoTask = Task {
            while !Task.isCancelled && demoTranscriptIndex < demoTranscript.count {
                let line = demoTranscript[demoTranscriptIndex]

                await MainActor.run {
                    if originalText.isEmpty {
                        originalText = line.original
                    } else {
                        originalText += "\n\n" + line.original
                    }

                    demoTranscriptIndex += 1
                    translatedText = demoTranslationText()
                }

                try? await Task.sleep(for: .seconds(1.2))
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                recordingState = .idle
                updateStatusMessage()
            }
        }
    }

    private func demoTranslationText() -> String {
        guard !originalText.isEmpty else { return "" }
        guard sourceLanguage != targetLanguage else { return originalText }

        let visibleItems = demoTranscript.prefix(demoTranscriptIndex)

        return visibleItems.map { item in
            item.translations[targetLanguage] ?? "[\(targetLanguage.rawValue)] \(item.original)"
        }
        .joined(separator: "\n\n")
    }

    private var isSimulatorEnvironment: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private var llmProvider: LLMProvider {
        LLMProvider(rawValue: llmProviderRawValue) ?? .openAI
    }

    @ViewBuilder
    private var contentLayout: some View {
        if isPadLayout {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 24) {
                    HeaderView(
                        recordingState: recordingState,
                        statusMessage: statusMessage,
                        recognizerAvailable: recognizerAvailable,
                        openSettings: { showingLLMSettings = true }
                    )

                    LanguageSelectorView(
                        sourceLanguage: $sourceLanguage,
                        targetLanguage: $targetLanguage
                    )

                    ControlBarView(
                        recordingState: recordingState,
                        startAction: startRecording,
                        pauseAction: pauseRecording,
                        resumeAction: resumeRecording,
                        stopAction: stopRecording
                    )

                    FooterCreditView()
                }
                .frame(maxWidth: 360, alignment: .topLeading)

                TranscriptView(
                    originalText: originalText,
                    translatedText: translatedText,
                    recordingState: recordingState,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    copiedSection: copiedSection,
                    copyOriginal: copyOriginalText,
                    copyTranslated: copyTranslatedText
                )
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(
                    recordingState: recordingState,
                    statusMessage: statusMessage,
                    recognizerAvailable: recognizerAvailable,
                    openSettings: { showingLLMSettings = true }
                )

                LanguageSelectorView(
                    sourceLanguage: $sourceLanguage,
                    targetLanguage: $targetLanguage
                )

                TranscriptView(
                    originalText: originalText,
                    translatedText: translatedText,
                    recordingState: recordingState,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    copiedSection: copiedSection,
                    copyOriginal: copyOriginalText,
                    copyTranslated: copyTranslatedText
                )

                ControlBarView(
                    recordingState: recordingState,
                    startAction: startRecording,
                    pauseAction: pauseRecording,
                    resumeAction: resumeRecording,
                    stopAction: stopRecording
                )

                FooterCreditView()
            }
        }
    }

    private var isPadLayout: Bool {
        horizontalSizeClass == .regular
    }
}

// MARK: - Header

struct HeaderView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let recordingState: RecordingState
    let statusMessage: String
    let recognizerAvailable: Bool
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 8 : 10) {
            HStack(alignment: .top) {
                Text("ListenNow")
                    .font(AppTypography.bold(isCompactLayout ? 30 : 34))

                Spacer()

                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text(statusMessage)
                .font(AppTypography.regular(isCompactLayout ? 14 : 15))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if recordingState != .idle {
                    StatusPill(recordingState: recordingState)
                }

                if !recognizerAvailable {
                    Label("Recognition Unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.bold(12))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

// MARK: - Language Selector

struct LanguageSelectorView: View {
    @Binding var sourceLanguage: AppLanguage
    @Binding var targetLanguage: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            LanguageMenu(title: "Source", selected: $sourceLanguage)

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            LanguageMenu(title: "Target", selected: $targetLanguage)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }
}

struct LanguageMenu: View {
    let title: String
    @Binding var selected: AppLanguage

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button(language.rawValue) {
                    selected = language
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.regular(12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(selected.rawValue)
                        .font(AppTypography.bold(17))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EngineSettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var speechEngine: SpeechEngine
    @Binding var translationEngine: TranslationEngine
    @Binding var llmProvider: LLMProvider
    @Binding var llmCorrectionEnabled: Bool
    @Binding var apiKey: String
    @Binding var model: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Speech") {
                    Picker("Transcription Engine", selection: $speechEngine) {
                        ForEach(SpeechEngine.allCases) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                }

                Section("Translation") {
                    Picker("Translation Engine", selection: $translationEngine) {
                        ForEach(TranslationEngine.allCases) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                }

                if speechEngine == .llm || translationEngine == .llm {
                    Section("LLM") {
                        Picker("Provider", selection: $llmProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }

                        SecureField("API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Model", text: $model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Correction") {
                    Toggle("Refine Apple STT with LLM", isOn: $llmCorrectionEnabled)
                }

                Section {
                    Text("LLM providers are separated so the app can support more than OpenAI. Right now, live API calls are connected for OpenAI translation and transcript refinement, while other providers and realtime LLM STT are planned for a later step.")
                        .font(AppTypography.regular(13))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .frame(minWidth: horizontalSizeClass == .regular ? 420 : nil)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Transcript View

struct TranscriptView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let originalText: String
    let translatedText: String
    let recordingState: RecordingState
    let sourceLanguage: AppLanguage
    let targetLanguage: AppLanguage
    let copiedSection: CopySection?
    let copyOriginal: () -> Void
    let copyTranslated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 16 : 20) {
            HStack {
                Text("LiveText")
                    .font(AppTypography.bold(21))

                Spacer()

                if recordingState == .recording {
                    LiveIndicator()
                } else if let copiedSection {
                    CopyToast(section: copiedSection)
                }
            }

            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 18) {
                    TranscriptSection(
                        title: "Original",
                        language: sourceLanguage.rawValue,
                        text: originalText,
                        placeholder: "Start speaking and the latest lines will continue to appear below.",
                        emphasis: .primary
                    )

                    TranscriptSection(
                        title: "Translation",
                        language: targetLanguage.rawValue,
                        text: translatedText,
                        placeholder: "Translated lines will appear here in real time.",
                        emphasis: .secondary
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    TranscriptSection(
                        title: "Original",
                        language: sourceLanguage.rawValue,
                        text: originalText,
                        placeholder: "Start speaking and the latest lines will continue to appear below.",
                        emphasis: .primary
                    )

                    Divider()

                    TranscriptSection(
                        title: "Translation",
                        language: targetLanguage.rawValue,
                        text: translatedText,
                        placeholder: "Translated lines will appear here in real time.",
                        emphasis: .secondary
                    )
                }
            }

            if recordingState == .idle && (!originalText.isEmpty || !translatedText.isEmpty) {
                CopyActionsView(
                    canCopyOriginal: !originalText.isEmpty,
                    canCopyTranslated: !translatedText.isEmpty,
                    copiedSection: copiedSection,
                    copyOriginal: copyOriginal,
                    copyTranslated: copyTranslated
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: isCompactLayout ? 390 : 460, alignment: .top)
        .padding(isCompactLayout ? 20 : 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 24, y: 14)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

struct TranscriptSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String
    let language: String
    let text: String
    let placeholder: String
    let emphasis: HierarchicalShapeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 8 : 10) {
            HStack {
                Text(title)
                    .font(AppTypography.bold(15))

                Text(language)
                    .font(AppTypography.bold(12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayText)
                            .font(AppTypography.regular(isCompactLayout ? 19 : 21))
                            .foregroundStyle(text.isEmpty ? .tertiary : emphasis)
                            .lineSpacing(isCompactLayout ? 4 : 5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: isCompactLayout ? 118 : 150)
                .onChange(of: text) { _, _ in
                    guard !text.isEmpty else { return }

                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var displayText: String {
        text.isEmpty ? placeholder : text
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

// MARK: - Control Bar

struct ControlBarView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let recordingState: RecordingState
    let startAction: () -> Void
    let pauseAction: () -> Void
    let resumeAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        Group {
            switch recordingState {
            case .idle:
                StartButton(action: startAction)

            case .recording:
                HStack(spacing: 12) {
                    SecondaryButton(title: "Pause", systemImage: "pause.fill", action: pauseAction)
                    TertiaryButton(title: "Stop", systemImage: "stop.fill", action: stopAction)
                }

            case .paused:
                HStack(spacing: 12) {
                    SecondaryButton(title: "Resume", systemImage: "play.fill", action: resumeAction)
                    TertiaryButton(title: "Stop", systemImage: "stop.fill", action: stopAction)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, isCompactLayout ? 14 : 16)
        .padding(.vertical, isCompactLayout ? 14 : 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

struct StartButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 20))

                Text("Start Listening")
                    .font(AppTypography.bold(isCompactLayout ? 16 : 17))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isCompactLayout ? 52 : 56)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

struct SecondaryButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.bold(isCompactLayout ? 14 : 15))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: isCompactLayout ? 48 : 52)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

struct TertiaryButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.bold(isCompactLayout ? 14 : 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: isCompactLayout ? 48 : 52)
        }
        .buttonStyle(.plain)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

struct FooterCreditView: View {
    var body: some View {
        Text("@ 2026 Designed by Key")
            .font(AppTypography.regular(11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let recordingState: RecordingState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recordingState == .recording ? Color.red : Color.orange)
                .frame(width: 8, height: 8)

            Text(recordingState == .recording ? "Listening" : "Paused")
                .font(AppTypography.bold(12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
}

struct LiveIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)

            Text("Listening")
                .font(AppTypography.bold(12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08), in: Capsule())
    }
}

struct CopyActionsView: View {
    let canCopyOriginal: Bool
    let canCopyTranslated: Bool
    let copiedSection: CopySection?
    let copyOriginal: () -> Void
    let copyTranslated: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if canCopyOriginal {
                CopyButton(
                    title: copiedSection == .original ? "Original Copied" : "Copy Original",
                    action: copyOriginal,
                    isCopied: copiedSection == .original
                )
            }

            if canCopyTranslated {
                CopyButton(
                    title: copiedSection == .translated ? "Translation Copied" : "Copy Translation",
                    action: copyTranslated,
                    isCopied: copiedSection == .translated
                )
            }
        }
    }
}

struct CopyButton: View {
    let title: String
    let action: () -> Void
    let isCopied: Bool

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isCopied ? "checkmark" : "doc.on.doc")
                .font(AppTypography.bold(14))
                .foregroundStyle(isCopied ? Color.green : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isCopied ? Color.green.opacity(0.12) : Color.white.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CopyToast: View {
    let section: CopySection

    var body: some View {
        Label("\(section.title) Copied", systemImage: "checkmark.circle.fill")
            .font(AppTypography.bold(12))
            .foregroundStyle(Color.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.green.opacity(0.1), in: Capsule())
    }
}

// MARK: - Speech

@MainActor
final class LiveSpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    var onTranscriptChange: ((String) -> Void)?
    var onAvailabilityChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var committedTranscript: String = ""
    private var liveTranscript: String = ""
    private var lastCommittedSegmentEndTime: TimeInterval = 0

    func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechAuthorized && microphoneAuthorized
    }

    func resetTranscript() {
        committedTranscript = ""
        liveTranscript = ""
        lastCommittedSegmentEndTime = 0
        publishTranscript()
    }

    func startListening(localeIdentifier: String) throws {
        stopListening()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw SpeechRecognizerError.unsupportedLocale
        }

        speechRecognizer = recognizer
        speechRecognizer?.delegate = self

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result {
                    self.updateTranscript(using: result)
                }

                if error != nil {
                    self.commitLiveTranscript()
                    self.stopListening()
                    self.onError?("Speech recognition could not continue. Please try again.")
                }
            }
        }
    }

    func pauseListening() {
        commitLiveTranscript()
        tearDownAudioSession()
    }

    func stopListening() {
        commitLiveTranscript()
        tearDownAudioSession()
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        onAvailabilityChange?(available)
    }

    private func publishTranscript() {
        let parts = [committedTranscript, liveTranscript]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        onTranscriptChange?(parts.joined(separator: "\n\n"))
    }

    private func commitLiveTranscript() {
        let trimmed = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if committedTranscript.isEmpty {
            committedTranscript = trimmed
        } else {
            committedTranscript += "\n\n" + trimmed
        }

        liveTranscript = ""
        publishTranscript()
    }

    private func updateTranscript(using result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription
        let liveSegments = transcription.segments.filter {
            ($0.timestamp + $0.duration) > lastCommittedSegmentEndTime
        }

        liveTranscript = liveSegments
            .map(\.substring)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.isFinal, let lastSegment = transcription.segments.last {
            commitLiveTranscript()
            lastCommittedSegmentEndTime = lastSegment.timestamp + lastSegment.duration
        }

        publishTranscript()
    }

    private func tearDownAudioSession() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            onError?("Could not reset the audio session.")
        }
    }
}

enum SpeechRecognizerError: LocalizedError {
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale:
            "Speech recognition is not available for the selected language."
        }
    }
}

enum LLMTranslationService {
    static func translate(
        text: String,
        sourceLanguage: AppLanguage,
        targetLanguage: AppLanguage,
        apiKey: String,
        model: String,
        provider: LLMProvider
    ) async throws -> String {
        guard provider == .openAI else {
            throw LLMServiceError.providerNotImplemented
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = """
        You are a translation engine.
        Translate the user's text from \(sourceLanguage.rawValue) to \(targetLanguage.rawValue).
        Return only the translated text.
        Preserve paragraph breaks.
        """

        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text)
            ],
            temperature: 0.2
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw LLMServiceError.emptyResponse
        }

        return content
    }

    static func correctTranscript(
        text: String,
        language: AppLanguage,
        apiKey: String,
        model: String,
        provider: LLMProvider
    ) async throws -> String {
        guard provider == .openAI else {
            throw LLMServiceError.providerNotImplemented
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = """
        You are a transcript correction engine.
        Clean up speech-to-text output in \(language.rawValue).
        Preserve meaning, sentence order, and paragraph breaks.
        Fix obvious recognition mistakes, spacing, punctuation, and casing.
        Do not summarize.
        Return only the corrected transcript.
        """

        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text)
            ],
            temperature: 0.1
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw LLMServiceError.emptyResponse
        }

        return content
    }
}

enum LLMTranscriptionService {
    static func transcribe(
        fileURL: URL,
        language: AppLanguage,
        apiKey: String,
        provider: LLMProvider
    ) async throws -> String {
        guard provider == .openAI else {
            throw LLMServiceError.providerNotImplemented
        }

        let boundary = UUID().uuidString
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        var body = Data()

        body.appendMultipartField(named: "model", value: "gpt-4o-mini-transcribe", boundary: boundary)
        body.appendMultipartField(named: "language", value: language.translationLanguage.languageCode?.identifier ?? "en", boundary: boundary)
        body.appendMultipartFile(
            named: "file",
            filename: fileURL.lastPathComponent,
            mimeType: "audio/m4a",
            fileData: audioData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AudioTranscriptionResponse.self, from: data)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw LLMServiceError.emptyResponse
        }

        return text
    }
}

@MainActor
final class LLMRecorder {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(resetFile: Bool) throws {
        if resetFile || recordingURL == nil {
            recordingURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("listennow-llm-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
        }

        guard let recordingURL else {
            throw LLMServiceError.invalidResponse
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()
    }

    func pauseRecording() {
        recorder?.pause()
    }

    func resumeRecording() throws {
        guard let recorder else {
            try startRecording(resetFile: false)
            return
        }

        recorder.record()
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }
}

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatMessage: Encodable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
    }
}

struct AudioTranscriptionResponse: Decodable {
    let text: String
}

enum LLMServiceError: Error {
    case providerNotImplemented
    case invalidResponse
    case emptyResponse
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(named name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        named name: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
