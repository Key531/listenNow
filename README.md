# ListenNow

ListenNow is a SwiftUI app for live speech capture, transcript refinement, and translation across multiple languages.

## Current scope

- Apple-style minimal interface for iPhone and iPad
- iPad landscape-adaptive layout
- Live transcript UI with auto-scrolling
- Copy actions for original and translated text
- Apple Speech-based transcription flow
- Apple Translation-based translation flow
- Optional LLM-based transcript refinement and translation
- Simulator demo mode for UI validation without a physical device

## Project structure

- `ListenNow/ListenNow/ContentView.swift`: main app UI and interaction flow
- `ListenNow/ListenNow/ListenNowApp.swift`: app entry point
- `ListenNow/ListenNowTests`: unit tests
- `ListenNow/ListenNowUITests`: UI tests

## Requirements

- Xcode 16 or later
- iOS 18 or later recommended
- Apple Developer team configuration for on-device install

## Running locally

1. Open `ListenNow/ListenNow.xcodeproj` in Xcode.
2. Choose a simulator to validate the UI and demo flow.
3. Choose a physical iPhone or iPad to test microphone, Speech, and Translation behavior.
4. Configure `Signing & Capabilities` with your Apple Developer team before running on device.

## Notes

- Simulator mode is useful for layout, navigation, copy actions, and demo transcript flow.
- Real microphone input and production-like speech behavior should be verified on a physical device.
- LLM features require a user-provided API key in the app settings.

