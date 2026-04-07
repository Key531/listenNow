# ListenNow

ListenNow is a SwiftUI app for live speech capture, transcript refinement, and translation across multiple languages.

Minimal UI, live transcript flow, Apple speech and translation support, and optional LLM-powered refinement are all built into a single SwiftUI experience.

## Highlights

- Minimal Apple-style interface
- iPhone and iPad adaptive layout
- Live transcript view with auto-scroll
- Copy actions for original and translated text
- Apple Speech transcription
- Apple Translation support
- Optional LLM transcript refinement and translation
- Simulator demo mode for UI validation

## Preview

Preview image will be added after the next exported screenshot pass.

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

## Runtime modes

- Simulator: demo transcript stream and UI validation
- Physical device: real microphone, Speech, Translation, and LLM-backed flows

## LLM settings

- LLM features are optional
- Users can enter their own API key in the in-app settings
- Apple-based speech and translation modes still work without external credentials

## Notes

- Simulator mode is useful for layout, navigation, copy actions, and demo transcript flow.
- Real microphone input and production-like speech behavior should be verified on a physical device.
- LLM features require a user-provided API key in the app settings.
