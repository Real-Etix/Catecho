# First-launch Setup Implementation Plan

**Goal:** Let a new user choose topics, language, and login startup inside Catecho's radio.
**Architecture:** SetupLifecycle handles migration/completion; RadioModel commits choices and gates fetching; RadioSetupView owns draft selection and navigation. RadioLoginItem wraps ServiceManagement with injected operations for testing and a reusable control for setup/settings.
**Tech Stack:** SwiftUI, AppKit, ServiceManagement, macOS 14+, existing shell build/tests.

## Constraints
- Keep the existing radio dimensions, Classic/Flat materials, language support, bundle identity and saved data.
- Login registration requires an explicit user switch and real status; approval/failure must not be represented as enabled.
- Existing users retain choices and normal tucked startup. New users can skip and reopen setup.

## Tasks
- [x] Write failing lifecycle and model tests in Tests/Setup/main.swift: fresh install, interruption, migration, validation, completion persistence, fetch gating and selected-station warmup.
- [x] Implement Sources/Core/SetupLifecycle.swift and integrate Sources/App/RadioModel.swift. Add injectable preferences/cache for isolated tests. Run the setup tests.
- [x] Implement and test Sources/App/RadioLoginItem.swift: actual status, idempotent on/off, approval required, failures and unavailable installation location.
- [x] Build Sources/App/RadioSetupView.swift from existing shell, switches and controls. Add all copy in RadioLanguage.swift. Integrate initial reveal, reopening and Escape/outside-click behavior in DesktopController/RadioView; add login control to RadioSettings.
- [x] Run ./test.sh, ./build.sh and native diagnostics. Inspect all three setup steps in English and both Chinese scripts using an isolated app. Check first-launch/relaunch and migrated preferences.
- [x] Update documentation, version and app archive. Safely update /Applications/Catecho.app after checking for unsaved settings. Verify real login status and preserve preferences. Release source and the app archive through the established GitHub beta workflow; record the final download check in the release handoff.
