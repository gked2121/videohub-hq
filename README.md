# VideoHub HQ

A native macOS app for creating AI-powered videos with [Claude Code](https://claude.ai/code) and [HyperFrames](https://github.com/heygen-com/hyperframes).

Type a prompt, hit Generate, and Claude Code builds a full HyperFrames video composition -- scenes, GSAP animations, transitions, typography, and all.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## Features

- **AI Video Generation** -- Describe your video in plain text. Claude Code generates a complete HyperFrames project with HTML compositions, GSAP animations, and transitions.
- **Auto-Thumbnails** -- After generation, automatically captures key frame PNGs via `hyperframes snapshot` and displays them in the app.
- **Live Output Streaming** -- Watch Claude Code's progress in a collapsible log panel as it builds your project.
- **Recent Projects** -- Your last 10 projects are saved for quick relaunch. Double-click to preview.
- **Onboarding** -- First-launch overlay explains both modes (Create and Projects) so new users get started fast.
- **Keyboard Shortcuts** -- Cmd+Return to generate. No mouse required.
- **Pulsing Animations** -- Custom 3-dot loading animation during generation instead of a generic spinner.
- **Dark Theme** -- Sand and terra cotta accents on dark backgrounds. No purple.

## Prerequisites

- **macOS 13+** (Ventura or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) installed (`npm install -g @anthropic-ai/claude-code`)
- [HyperFrames](https://github.com/heygen-com/hyperframes) available via npx (`npx hyperframes`)
- Node.js 18+

## Quick Start

```bash
git clone https://github.com/gked2121/videohub-hq.git
cd videohub-hq
./build.sh
```

The app lands on your Desktop. Double-click to launch.

To compile manually:

```bash
swiftc -o VideoHubHQ VideoHubHQ.swift -framework SwiftUI -framework AppKit -parse-as-library
```

Then package into a `.app` bundle (see `build.sh` for the full structure).

## How It Works

1. **Type a prompt** -- e.g. "30-second LinkedIn video about AI agents for enterprise"
2. **Claude Code generates the project** -- runs headlessly via `claude --print`, creates HTML compositions with GSAP animations
3. **Thumbnails are captured** -- `hyperframes snapshot` runs automatically, key frames displayed in the app
4. **Preview in HyperFrames Studio** -- hit Preview to open the browser-based editor for playback and rendering

Generated projects are saved to `~/Desktop/videohub-projects/`.

## Screenshots

<!-- Add screenshot of Create tab here -->
<!-- Add screenshot of Projects tab here -->
<!-- Add screenshot of Onboarding overlay here -->

## Tech Stack

- **SwiftUI** -- native macOS app, instant launch, smooth animations
- **Claude Code CLI** -- AI-powered code generation running as a subprocess
- **HyperFrames + GSAP** -- HTML-to-video rendering framework by HeyGen
- Dark UI with warm earth tones (sand, terra cotta)

## Project Structure

```
videohub-hq/
  VideoHubHQ.swift   -- Single-file SwiftUI app (entire source)
  Info.plist         -- macOS app bundle metadata
  build.sh           -- Build + package script
  LICENSE            -- MIT
```

## License

MIT
