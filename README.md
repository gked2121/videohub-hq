# VideoHub HQ

A native macOS app for creating AI-powered videos with [Claude Code](https://claude.ai/code) and [HyperFrames](https://github.com/heygen-com/hyperframes).

Type a prompt, hit Generate, and Claude Code builds a full HyperFrames video composition for you -- scenes, animations, transitions, typography, and all.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## What It Does

**Create** -- Describe the video you want in plain text. VideoHub HQ runs Claude Code headlessly to scaffold a complete HyperFrames project (HTML compositions, GSAP animations, transitions, color palettes). Output streams live into the app.

**Projects** -- Open, preview, and manage your HyperFrames projects. Recent projects are saved for quick relaunch.

## Prerequisites

- **macOS 13+** (Ventura or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) installed (`npm install -g @anthropic-ai/claude-code`)
- [HyperFrames](https://github.com/heygen-com/hyperframes) available via npx (`npx hyperframes`)
- Node.js 18+

## Quick Start

### Option 1: Build from source

```bash
git clone https://github.com/gked2121/videohub-hq.git
cd videohub-hq
./build.sh
```

The app lands on your Desktop. Double-click to launch.

### Option 2: Manual compile

```bash
swiftc -o VideoHubHQ VideoHubHQ.swift -framework SwiftUI -framework AppKit -parse-as-library
```

Then package into a `.app` bundle (see `build.sh` for the structure).

## How It Works

1. **You type a prompt** -- e.g. "30-second LinkedIn video about AI agents for enterprise"
2. **Claude Code runs headlessly** -- using `claude --print --dangerously-skip-permissions` to generate a complete HyperFrames project
3. **Output streams in real time** -- watch Claude's progress in the collapsible log panel
4. **Hit Preview** -- opens HyperFrames Studio in your browser to preview and render the video

Generated projects are saved to `~/Desktop/videohub-projects/`.

## Tech Stack

- **SwiftUI** -- native macOS app, instant launch, smooth animations
- **Claude Code CLI** -- AI-powered code generation running as a subprocess
- **HyperFrames** -- HTML-to-video rendering framework by HeyGen
- Dark UI with warm earth tones (sand, terra cotta)

## Project Structure

```
videohub-hq/
  VideoHubHQ.swift   -- Single-file SwiftUI app (entire source)
  Info.plist         -- macOS app bundle metadata
  build.sh           -- Build + package script
```

## License

MIT
