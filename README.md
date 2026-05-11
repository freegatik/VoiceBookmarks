<p align="center">
  <img src="logo.png" width="200" alt="Voice Bookmarks">
</p>

# Voice Bookmarks

![Static Badge](https://img.shields.io/badge/platform-iOS-white)
![Static Badge](https://img.shields.io/badge/latest_release-v1.0.0-green)
![Static Badge](https://img.shields.io/badge/swift-v5.0-orange)

[![iOS CI](https://github.com/freegatik/VoiceBookmarks/actions/workflows/ios.yml/badge.svg)](https://github.com/freegatik/VoiceBookmarks/actions/workflows/ios.yml)

Native **iOS** app (**SwiftUI** + **Combine**, Swift **5**, iOS **15.0** minimum) for saving and organizing content with **Russian speech** notes, **semantic search**, and a **Share Extension**. **MVVM** with injected services (**URLSession**, **Core Data** offline queue, **Keychain**, **App Groups**). No third-party app dependencies beyond Apple frameworks. API contract: [swagger.yaml](swagger.yaml). Full setup (URLs, bundle IDs, App Groups, URL scheme): **[CONFIGURATION.md](CONFIGURATION.md)**.

## CI

Single workflow [`.github/workflows/ios.yml`](.github/workflows/ios.yml) on [GitHub Actions](https://github.com/freegatik/VoiceBookmarks/actions) for **`push`** / **`pull_request`** on **`main`**. **`concurrency`** with **`cancel-in-progress`** deduplicates runs per ref.

| Stage | What it runs |
|-------|----------------|
| **Toolchain** | `maxim-lobanov/setup-xcode@v1` with **`latest-stable`**; logs Xcode + SDK + first simulator lines |
| **Packages** | `xcodebuild -resolvePackageDependencies` for **`VoiceBookmarks`** |
| **Static checks** | Fails on **`TODO`/`FIXME`** in app + extension sources; fails on **duplicate Swift basenames** |
| **Unit tests** | [`Scripts/ci/run-ios-tests.sh`](Scripts/ci/run-ios-tests.sh) **`main-unit`** → **`VoiceBookmarksTests`**, coverage, **`TestResults-main.xcresult`** |
| **UI tests** | **`main-ui`** → **`VoiceBookmarksUITests`** (stricter timeouts, single concurrent destination) |
| **Share tests** | **`share`** → **`VoiceBookmarksShareExtensionTests`** + **`VoiceBookmarksShareExtensionUITests`** |
| **Artifacts** | Packs available **`.xcresult`** bundles into **`ios-test-results.zip`** and uploads (**`compression-level: 0`**) on **`always()`** |
| **Coverage** | On success, **`xcrun xccov view --report`** on **`TestResults-main.xcresult`** (tail in log) |
| **Backend smoke** | Optional **`curl`** to anonymous auth URL (**`continue-on-error: true`**) |

Simulator **`IOS_DESTINATION`** in CI defaults to **`platform=iOS Simulator,name=iPhone 16,OS=18.2`** (see workflow and script). CI defines **`VOICEBOOKMARKS_CI`** for builds so the simulator can skip live-audio paths.

## Requirements

- **Xcode 15+** (workflow uses **latest-stable** Xcode on **`macos-14`**)
- **iOS 15.0+** deployment target; use a simulator profile compatible with your machine (CI pins **iPhone 16, iOS 18.2** when available on the runner)

## Getting started

```bash
git clone https://github.com/freegatik/VoiceBookmarks.git
cd VoiceBookmarks
open VoiceBookmarks.xcodeproj
```

Use the **VoiceBookmarks** scheme: **⌘R** to run, **⌘U** for tests. Before real API use, follow **[CONFIGURATION.md](CONFIGURATION.md)** (`VoiceBookmarks/Utils/Constants.swift`, signing, App Groups, URL scheme).

## Project layout

| Area | Path / notes |
|------|----------------|
| App entry & DI | `VoiceBookmarks/App/` |
| Models | `VoiceBookmarks/Models/` |
| Views & tabs | `VoiceBookmarks/Views/` (`Search/`, `Share/`, `WebView/`, `Components/`) |
| View models | `VoiceBookmarks/ViewModels/` |
| Services | `VoiceBookmarks/Services/` (`API/`, `Core/`) |
| Persistence | `VoiceBookmarks/Persistence/` (Core Data) |
| Utilities | `VoiceBookmarks/Utils/` (`Constants.swift`, extensions) |
| Share extension | `VoiceBookmarksShareExtension/` |
| Unit tests | `VoiceBookmarksTests/`, `VoiceBookmarksShareExtensionTests/` |
| UI tests | `VoiceBookmarksUITests/`, `VoiceBookmarksShareExtensionUITests/` |
| CI helpers | [`Scripts/ci/run-ios-tests.sh`](Scripts/ci/run-ios-tests.sh) |

## Testing

CI runs **unit**, **main app UI**, and **Share extension** suites separately via **`run-ios-tests.sh`**. Locally you can mirror phases:

```bash
chmod +x Scripts/ci/run-ios-tests.sh
export IOS_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.2'   # adjust to your sim
Scripts/ci/run-ios-tests.sh main-unit
Scripts/ci/run-ios-tests.sh main-ui
Scripts/ci/run-ios-tests.sh share
```

UI test launch arguments (e.g. seeding) are documented in the existing project docs and test sources. Coverage summary from a local unit run:

```bash
xcrun xccov view --report TestResults-main.xcresult | head -40
```

## API & docs

- **OpenAPI**: [swagger.yaml](swagger.yaml)  
- **Backend setup & identifiers**: [CONFIGURATION.md](CONFIGURATION.md)  

## Contributing

Pull requests are welcome. Please keep CI green (`TODO`/`FIXME` and duplicate-basename checks are enforced).

## License

[Apache License 2.0](LICENSE).
