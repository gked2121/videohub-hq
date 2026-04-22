# VideoHub

Create AI-powered videos using HyperFrames. This skill handles the full pipeline: scaffold a project, build polished HTML video compositions with GSAP animations, validate, capture thumbnails, and preview in HyperFrames Studio.

## When to Use

Invoke this skill when the user asks to:
- Make a video, create a video, build a video
- "Use VideoHub" or "VideoHub HQ"
- Create a HyperFrames composition or project
- Generate video content for social media, marketing, demos, tutorials, etc.
- Create an animated explainer, product demo, or announcement video

## Full Pipeline

Follow these steps in order. Do not skip steps.

### Step 1: Scaffold the Project

```bash
mkdir -p ~/Desktop/videohub-projects
cd ~/Desktop/videohub-projects
npx hyperframes init <project-name> --non-interactive --skip-skills
cd <project-name>
```

This creates the project directory with `hyperframes.json`, `meta.json`, and an initial `index.html` composition.

### Step 2: Plan Before Coding

Before writing any HTML:

1. **Interpret the prompt.** Generate real content -- not placeholder text. A product demo shows real features. A testimonial uses realistic quotes. Never use lorem ipsum.
2. **Plan scenes.** Break the video into 4-7 scenes. Each scene should have a clear purpose:
   - Scene 1: Hook / Title (grab attention in first 3 seconds)
   - Scenes 2-5: Core content (one idea per scene)
   - Final scene: CTA / Closing
3. **Declare your palette.** Choose background, foreground, and accent BEFORE writing code:
   - Dark backgrounds for tech, finance, cinema: `#141412`, `#0D0D0C`, `#1A1918`
   - Light backgrounds for food, wellness, lifestyle: `#FAF7F2`, `#F5F0E8`
   - Accent: one hue only. Tint all neutrals toward it.
   - Never use pure `#000` or `#fff` -- tint toward your accent
   - Never use purple unless explicitly requested
   - Default: sand (#D9BF94) + terra cotta (#C7804E) on dark (#141412)
4. **Pick typefaces.** Mix serif + sans-serif (never two sans-serifs). Use Google Fonts via `@import`. Headlines: 700-900 weight, 60px+. Body: 300-400 weight, 20px+.

### Step 3: Build the Composition

Create or replace `index.html` in the project directory. The composition is a self-contained HTML file.

#### HTML Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=1920, height=1080">
    <style>
        /* All styles inline */
    </style>
</head>
<body>
    <div data-composition-id="main" data-start="0" data-duration="30">
        <!-- Scene 1 -->
        <div data-scene="1" data-start="0" data-duration="6">
            <!-- Background layer (decoratives) -->
            <!-- Content layer -->
        </div>
        <!-- Scene 2 -->
        <div data-scene="2" data-start="6" data-duration="6" style="opacity: 0;">
            <!-- ... -->
        </div>
        <!-- More scenes... -->
    </div>

    <script src="https://cdn.jsdelivr.net/npm/gsap@3/dist/gsap.min.js"></script>
    <script>
        // Timeline and animations
    </script>
</body>
</html>
```

#### Critical Rules

- **Canvas:** Always 1920x1080. Set `width: 1920px; height: 1080px;` on the root composition div.
- **Scene 1:** Visible by default (no `opacity: 0`). All other scenes start with `opacity: 0` on their container div.
- **Scene transitions:** Use GSAP to fade/animate scenes in and out. Never use CSS transitions for scene changes.
- **Fonts:** Write the `font-family` you want -- the HyperFrames compiler handles embedding automatically. No need for `<link>` tags.
- **No external assets:** Everything inline. No external images unless the user provides URLs. Use CSS gradients, shapes, and SVG for visuals.

#### Background Layer (Required for Every Scene)

Every scene MUST have persistent decorative elements that stay visible while content animates in. Without these, scenes feel empty during entrance staggering. Use 2-5 of these per scene:

- Radial glows: accent-tinted, low opacity (5-15%), breathing scale animation
- Ghost text: theme keywords at 3-8% opacity, very large (200px+), slow drift
- Accent lines: hairline rules with subtle pulse animation
- Geometric shapes: circles, grids, diagonal lines at low opacity
- Grain/noise overlays
- Thematic decoratives: orbit rings for space, waveforms for audio, grid lines for data

ALL decoratives must have slow ambient GSAP animation (breathing, drift, pulse). Static decoratives look dead.

#### Motion & Animation Rules

- **Durations:** 0.3-0.6s for entrances. Never slower than 1s for a single element.
- **Easing:** Vary eases -- don't use the same ease for every animation. Mix `power2.out`, `power3.inOut`, `back.out(1.7)`, `elastic.out(1, 0.5)`.
- **Entrances:** Combine transforms. `y: 30, opacity: 0` is better than just `opacity: 0`. Add subtle rotation or scale for variety.
- **Staggering:** Overlap entries -- don't wait for one animation to finish before starting the next. Use `stagger: 0.08` to `stagger: 0.15`.
- **Scene transitions:** Use `fromTo` to animate scene containers. Fade + slight scale or slide works well.

#### Typography

- Headlines: weight 700-900, size 60px+ (up to 120px for hero text)
- Body text: weight 300-400, size 20-28px
- Use serif for headlines + sans-serif for body, or vice versa
- Line height: 1.1-1.2 for headlines, 1.5-1.6 for body
- Letter-spacing: -0.02em for large headlines, 0.02-0.05em for small labels

#### Avoid These (AI Design Tells)

These patterns make videos look AI-generated. Only use them if genuinely appropriate:

- Gradient text (`background-clip: text`) -- overused
- Left-edge accent stripes on cards
- Cyan-on-dark or purple-to-blue gradients
- Identical card grids (same-size cards repeated)
- Everything centered with equal visual weight
- Neon glow effects on everything

### Step 4: Validate

```bash
npx hyperframes lint
```

Fix all lint errors. Common issues:
- Missing `data-duration` on scenes
- Scene timing gaps or overlaps
- WCAG contrast violations (text must be readable without decoratives)

### Step 5: Capture Thumbnails

```bash
npx hyperframes snapshot
```

Saves 5 key frame PNGs to `snapshots/` directory at 0%, 25%, 50%, 75%, and 100% of the composition.

### Step 6: Preview

```bash
npx hyperframes preview
```

Opens HyperFrames Studio on localhost:3002 for playback, editing, and rendering.

### Step 7: Render (if requested)

```bash
npx hyperframes render
```

Renders the composition to MP4 or WebM video file, saved to `renders/`.

## Video Specifications

Default values (override per user request):

| Setting | Default | Options |
|---------|---------|---------|
| Duration | 30 seconds | 15s, 30s, 45s, 60s, 90s |
| Style | Dark Premium | Clean Corporate, Bold Energetic, Warm Editorial, Nature Earth, Monochrome |
| Colors | Sand & Terra Cotta | Warm Neutrals, Cool Steel, Forest & Gold, Coral & Cream |
| Speed | Medium | Slow, Medium, Fast, Dynamic |
| Resolution | 1920x1080 | Fixed |
| Goal | Marketing | Product Demo, Social Media, Explainer, Announcement, Tutorial, Testimonial |

## Output Location

Always create projects in `~/Desktop/videohub-projects/<project-name>/`. This is the default directory VideoHub HQ scans for projects.

## Color Palettes

### Dark Premium (default)
- Background: `#141412`
- Foreground: `#EDE8DE`
- Accent: `#D9BF94` (sand), `#C7804E` (terra cotta)
- Dim text: `#8C8A82`

### Clean Corporate
- Background: `#F8F6F3`
- Foreground: `#1A1A1A`
- Accent: `#2B5EA7`

### Bold Energetic
- Background: `#0F0F0F`
- Foreground: `#FFFFFF`
- Accent: `#FF4D00`

### Warm Editorial
- Background: `#F5EDE3`
- Foreground: `#2C2420`
- Accent: `#B85C38`

### Nature Earth
- Background: `#1B2420`
- Foreground: `#E8E0D4`
- Accent: `#7BA05B`

### Monochrome
- Background: `#0C0C0C`
- Foreground: `#E8E8E8`
- Accent: `#888888`

## Example Prompts

### Simple
"Make a 30-second video about our new AI product"

### Detailed
"Create a 60-second LinkedIn video for enterprise decision-makers about managed AI agents. Use dark premium style, sand and terra cotta colors, medium animation speed. 5 scenes: hook with bold stat, problem statement, solution overview, 3 key features, CTA to book a demo."

### With specifics
"Build a 15-second Instagram Reel announcing our Series A funding. Bold energetic style, fast animations. Show the amount ($12M), key investors, and what we're building next."

## VideoHub HQ App

VideoHub HQ is a native macOS app that provides a GUI for this entire pipeline. Users can also use it to:
- Type prompts with advanced options (duration, style, colors, speed, goal)
- Watch Claude Code generate the project in real-time via a built-in terminal
- Track progress with a visual progress bar
- Capture thumbnails with one click
- Preview videos with an embedded HyperFrames Studio view + thumbnail sidebar
- Manage recent projects

Install: `git clone https://github.com/gked2121/videohub-hq && cd videohub-hq && ./build.sh`

## Additional HyperFrames Skills

For even more detailed composition guidance (full transition catalog, advanced typography rules, motion principles), install the HyperFrames design system skills:

```bash
npx skills add heygen-com/hyperframes
```

VideoHub works without them, but compositions are more polished with the full skill set installed.
