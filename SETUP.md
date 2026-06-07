# Setup Guide for Contributors

## First-time setup

### 1. Install tools

```bash
# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# xcodegen — generates the Xcode project from project.yml
brew install xcodegen
```

### 2. Generate the Xcode project

The `.xcodeproj` is **not committed to git** (it is generated). Run this once after cloning, and again any time you add/remove source files or change `project.yml`:

```bash
xcodegen generate
```

### 3. Open and build

```bash
open "Syntra.xcodeproj"
# Then press ⌘R to build and run
```

Swift Package Manager will automatically fetch **Sparkle** (auto-update) and **Lottie** (welcome animation) when you open the project.

---

## Adding new source files

1. Drop the `.swift` file into the correct folder under `Syntra/`
2. Run `xcodegen generate` again to pick it up
3. Re-open the project in Xcode

---

## Releasing a new version

Push a git tag and GitHub Actions will build both DMGs and create a GitHub Release automatically:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The release will contain:
- `Syntra-Syntra Desktop-1.2.0-arm64.dmg` (Apple Silicon)
- `Syntra-Syntra Desktop-1.2.0-x86_64.dmg` (Intel)

---

## Troubleshooting

### "xcodeproj not found"
Run `xcodegen generate` first.

### "Sparkle / Lottie not found"
Open the project in Xcode and let it resolve packages (`File → Packages → Resolve Package Versions`), or run:
```bash
xcodebuild -resolvePackageDependencies -project "Syntra.xcodeproj" -scheme "Syntra"
```

### Screen capture not working after granting permission
The app needs to be **restarted** after granting Screen Recording permission in System Settings. This is a macOS requirement. The onboarding flow handles this automatically.

### App blocked on first launch
Right-click the app → **Open** → **Open** (in the dialog). This only needs to be done once because the app is unsigned.
