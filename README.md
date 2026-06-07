# Syntra

An AI overlay for macOS — private, detection-free window for on-screen AI assistance.

> Inspired by [Cluely](https://cluely.com). Open source for the community.

---

## Download

Head to the [Releases](../../releases) page and download the DMG for your Mac:

| Mac Type | File |
|---|---|
| Apple Silicon (M1/M2/M3/M4) | `Syntra-Syntra Desktop-*-arm64.dmg` |
| Intel Mac | `Syntra-Syntra Desktop-*-x86_64.dmg` |

**Requires macOS 12.5 (Monterey) or later.**

### ⚠️ First-launch note (unsigned build)

Because these are open-source unsigned builds, macOS will block the first launch. To open:
1. Right-click the app → **Open**
2. Click **Open** again in the dialog

You only need to do this once.

---

## Permissions Required

On first launch, you'll be asked for two permissions — both are required:

| Permission | Why |
|---|---|
| **Accessibility** | Reads selected text in other apps and listens for global keyboard shortcuts |
| **Screen Recording** | Captures your screen for AI context (OCR + screenshot) |

---

## Building From Source

### Prerequisites

- macOS 12.5+
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/syntra-syntra.git
cd syntra-syntra

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode
open "Syntra.xcodeproj"

# 4. Build & run (⌘R)
```

Sparkle (auto-updater) is fetched automatically via Swift Package Manager when you open the project.

---

## Automatic DMG Builds (GitHub Actions)

DMGs are built automatically via GitHub Actions whenever you:

- **Push to `main`/`master`** → builds for both arm64 and x86_64, uploads as downloadable workflow artifacts
- **Push a version tag** (e.g. `git tag v1.0.0 && git push --tags`) → creates a GitHub Release with both DMGs attached

The workflow is at `.github/workflows/build.yml`.

---

## Architecture

| Module | Purpose |
|---|---|
| `AI/` | WebSocket connection to AI backend, context capture (OCR + screenshot + selected text) |
| `API/` | HTTP client for notes and context search API |
| `Auth/` | OAuth flow via `syntra://` URL scheme |
| `Overlay/` | Transparent floating windows (AI assist, quick capture, auto-context) |
| `InputEvent/` | Global keyboard shortcut listener (requires Accessibility permission) |
| `Setup/` | Onboarding flow, permission requests |
| `SystemMenu/` | macOS menu bar icon + Sparkle auto-update |
| `Settings/` | Appearance, shortcut configuration |

## Default Shortcuts

| Shortcut | Action |
|---|---|
| ⌘⇧1 | Toggle AI Assist overlay |
| ⌘⇧2 | Toggle Quick Capture overlay |
| ⌘⇧O | Toggle Auto Context overlay |

All shortcuts are configurable in Settings.

---

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) or open an issue to discuss.

## License

Non-commercial open source license. See [LICENSE](LICENSE).
