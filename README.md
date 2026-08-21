# Fcitx5 WeChat Theme

WeChat-style input method themes for [Fcitx5](https://github.com/fcitx/fcitx5), with a rime-ice memory patch and a ready-to-install `.deb` package.

![Light](screenshots/light-mode-exam.png) ![Dark](screenshots/dark-mode-exam.png)

> **⚠️ Before you start — know the two ways to use this theme.**
>
> - **Just want to try it** (no tweaking): run the install commands below and it works out of the box.
> - **Want pixel-perfect results after changing the font size / margins**: this theme uses **SVG-based highlight blocks**. The SVGs are tuned for **14px text** (see [Customization](#customization-diy)); if you bump the system font size without adjusting the SVG `rx`/margins, the highlight roundness breaks. Beginners should treat the shipped defaults as the recommended baseline and only tweak via the guide below.

## Features

- **Two SVG vector themes**: `wechat-light` (white, bright green highlight) and `wechat-dark` (translucent dark, muted green highlight).
- **True rounded corners**: rendered with SVG + nine-patch stretching, so the corners keep their radius no matter how many candidates are shown.
- **WeChat-matched geometry**: outer radius 10px, highlight radius 8px, 4/6px inner padding, 14px candidate text.
- **Rime memory patch**: speeds up dynamic frequency tuning so repeated words rise in the candidate list.
- **GNOME dark-mode switcher**: auto-switches between light/dark based on `org.gnome.desktop.interface color-scheme`.

## Requirements

SVG rendering needs fcitx5 classicui built with librsvg:

- fcitx5 **>= 5.1.22** (distro builds here).
- Ubuntu 26.04 ships fcitx5 **5.1.19** without SVG support — build from source, see [Build from source](#build-from-source).

## Installation

> **💡 One-click install (recommended):** if you want a **clean, from-zero
> environment** that ends up with *only* Rime + rime-ice (雾凇拼音) + the WeChat
> theme, run the bundled `install-all.sh` (see below). It removes other input
> method stacks, pulls the needed libraries, deploys the prebuilt SVG fcitx5,
> installs rime-ice + both themes, and configures fcitx5 to expose only
> "雾凇拼音". Validated in a fresh Ubuntu 26.04 Docker container.

### One-click install (entire environment) — `install-all.sh`

For a brand-new / clean Ubuntu (x86_64), the whole thing in one command:

```bash
sudo bash install-all.sh
```

This performs all **7 steps** automatically:

1. Removes any existing input-method stacks (ibus / fcitx / extra engines),
   keeping fcitx5 / librime / librsvg.
2. Installs the required system libraries, including the hard dependency
   `libxcb-ewmh2` (missing it makes the skin vanish while typing still works).
3. Deploys the bundled prebuilt **SVG fcitx5 5.1.22** (`packages/`) so real
   rounded corners render.
4. Installs the **rime-ice (雾凇拼音)** dictionary from `packages/rime-ice/`.
5. Installs `wechat-light` / `wechat-dark` themes.
6. Configures fcitx5: **only Rime enabled**, Chinese active by default,
   `Theme=wechat-light`.
7. Restarts fcitx5.

The bundled assets (`packages/`) ship with the repo, so **no network / GitHub
access is required** at install time — everything is local and offline.

> Details of what changed in this version are in
> [release-notes-v1.1.1.md](release-notes-v1.1.1.md).

---

> **Ubuntu 26.04 users need full SVG rounded corners.** The distro's
> fcitx5 (5.1.19) has no SVG support, so follow **Step 1** below first to
> install the prebuilt SVG fcitx5 (5.1.22), then **Step 2** to install the
> theme. On distros that ship fcitx5 >= 5.1.22 (Arch, Fedora, ...), skip
> Step 1 and go straight to Step 2.

### Step 1 — Install the prebuilt SVG fcitx5 (Ubuntu 26.04 / x86_64)

Download `fcitx5-svg-5.1.22-linux-x86_64.tar.gz` from the [Releases](https://github.com/OrangeAreFruit/Fcitx5-Wechat-Theme/releases) page, then run:

```bash
bash install-fcitx5-svg.sh ./fcitx5-svg-5.1.22-linux-x86_64.tar.gz
```

The script installs the apt base libraries, extracts the tarball, copies the
fcitx5 binaries/libraries/data to `/usr`, and refreshes the linker cache.

Verify SVG support:

```bash
ldd /usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so | grep librsvg
```

> To build this tarball yourself on a machine that already compiled fcitx5
> from source, run `bash package-fcitx5.sh`.

### Option A — .deb package (Step 2, install the theme)

Download `fcitx5-wechat-theme_1.1.1_amd64.deb` from the [Releases](https://github.com/OrangeAreFruit/Fcitx5-Wechat-Theme/releases) page, then:

```bash
sudo apt install ./fcitx5-wechat-theme_1.1.1_amd64.deb
```

The package installs both themes to `/usr/share/fcitx5/themes/`, sets `Theme=wechat-light` in `classicui.conf`, and restarts fcitx5.

To build the package yourself:

```bash
bash build-deb.sh        # → dist/fcitx5-wechat-theme_<ver>_amd64.deb
```

### Option B — script (user-level)

```bash
bash install.sh
```

Installs the themes to `~/.local/share/fcitx5/themes/`, the rime patch to `~/.local/share/fcitx5/rime/`, and restarts fcitx5.

To switch themes, edit `Theme=` in `~/.config/fcitx5/conf/classicui.conf` (`wechat-light` / `wechat-dark`).

## Build from source

Shipping fcitx5 on Ubuntu 26.04 lacks SVG support. To get vector rounded corners, compile fcitx5 master:

```bash
sudo apt install -y build-essential cmake ninja-build extra-cmake-modules \
  librsvg2-dev libxcb-imdkit-dev libxcb-randr0-dev libxkbfile-dev \
  libgirepository1.0-dev libgtk2.0-dev libgtk-3-dev libcairo2-dev \
  libwayland-dev wayland-protocols plasma-wayland-protocols \
  qtbase5-private-dev qt6-base-private-dev libdbus-1-dev

git clone --depth=1 https://github.com/fcitx/fcitx5 && cd fcitx5
git submodule update --init --recursive          # required (yoga, etc.)
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DENABLE_TEST=OFF
cmake --build build -j"$(nproc)" && sudo cmake --install build

# Rime engine (needed for rime-ice)
cd .. && git clone --depth=1 https://github.com/fcitx/fcitx5-rime && cd fcitx5-rime
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)" && sudo cmake --install build

# GTK / QT frontends (candidate positioning)
cd .. && git clone --depth=1 https://github.com/fcitx/fcitx5-gtk && cd fcitx5-gtk
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)" && sudo cmake --install build

cd .. && git clone --depth=1 https://github.com/fcitx/fcitx5-qt && cd fcitx5-qt
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)" && sudo cmake --install build

sudo ldconfig
```

Verify SVG support:

```bash
ldd /usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so | grep librsvg
```

> Building over an `apt`-managed fcitx5 overwrites its files. Keep a system snapshot (e.g. `sudo timeshift --create`) before proceeding.

## Project structure

```
fcitx5-wechat-theme/
├── install.sh              # User-level installer (themes + rime patch)
├── install-all.sh          # ★ One-click full environment installer (7 steps)
├── install-fcitx5-svg.sh   # Installs the prebuilt SVG fcitx5 tarball
├── build-deb.sh            # Builds the .deb package
├── package-fcitx5.sh       # Builds the fcitx5-svg tarball
├── theme-switcher.sh       # GNOME dark-mode auto switcher
├── packages/               # Bundled offline assets used by install-all.sh
│   ├── fcitx5-svg-5.1.22-linux-x86_64.tar.gz   # prebuilt SVG fcitx5
│   ├── rime-ice/           # rime-ice (雾凇拼音) dictionary
│   └── themes/             # wechat-light / wechat-dark
├── release-notes-v1.1.1.md # Changelog for v1.1.1
├── fcitx5/
│   ├── themes/
│   │   ├── wechat-light/   # theme.conf + panel.svg + highlight.svg
│   │   └── wechat-dark/
│   └── rime_ice.custom.yaml
├── screenshots/            # Preview images
└── dist/                   # build outputs (.deb + .tar.gz, gitignored)
```

## Customization (DIY)

This is where it gets hands-on. The default theme is **designed for 14px text**,
and all visual parameters live in one plain-text file — there's no CSS and no
compiled code, so editing is as simple as changing a number and reloading:

```ini
# ~/.config/fcitx5/conf/classicui.conf
Font="Noto Sans CJK SC 14"     # ← change the trailing number to resize
```

```ini
# <theme>/theme.conf                      (wechat-light or wechat-dark)
[InputPanel/TextMargin]      Left/Right=8  Top/Bottom=6   # space around the text
[InputPanel/ContentMargin]   Left/Right=4  Top/Bottom=6   # gap between highlight block and panel edge
[InputPanel/Highlight/Margin] Left/Right=8 Top/Bottom=8   # corner protection (must == SVG rx)
[InputPanel/Background/Margin] Left/Right=10 Top/Bottom=10# corner protection (must == SVG rx)
```

### Where the knobs are (for non-developers)

All the geometry you care about is in that one `theme.conf` file:

- **Highlight block (the selected candidate)** — `Highlight/Margin` is its
  **outer** spacing; `Highlight/.../Color` is its fill. Its **corner roundness**
  actually comes from `highlight.svg` (`rx`), not from CSS.
- **Panel (the popup frame)** — `Background` color + `Background/Margin`
  (outer corners). Panel roundness comes from `panel.svg` (`rx`).
- **Spacing between highlight and panel edge** — `ContentMargin`.
- **Spacing between text and its cell** — `TextMargin`.

> **Margin vs padding — don't confuse them.** There are no `padding-*` keys in
> this theme; fcitx5 uses only "margins" for the spacing layers, plus the SVG
> `rx` for roundness. `Margin` = protected corner strip (keeps the radius);
> `ContentMargin` = gap between highlight and panel. Changing one rarely needs
> the other touched.

### Reference baseline (the values we tuned by hand)

The following set is what was dialed in through real visual iteration against
WeChat and ships with the theme. It's a solid starting point:

| Layer | Setting | Value |
|-------|---------|-------|
| Font size | `classicui.conf` `Font` | `14` |
| Outer panel roundness | `panel.svg` `rx` + `Background/Margin` | `10` |
| Inner highlight roundness | `highlight.svg` `rx` + `Highlight/Margin` | `8` |
| Highlight ↔ panel spacing | `ContentMargin` | L/R `4`, T/B `6` |
| Text ↔ cell spacing | `TextMargin` | L/R `8`, T/B `6` |
| Light highlight color | `HighlightBackgroundColor` (light) | `#34B950` |
| Dark highlight color | `HighlightBackgroundColor` (dark) | `#279E42` |

**The golden rule** that stops the roundness from vanishing: a layer's SVG
`rx` **must equal** that layer's `Margin` (e.g. highlight `rx=8` ↔
`Highlight/Margin=8`). The nine-patch keeps the four corners fixed and only
stretches the middle, so as long as `rx == Margin`, the corner survives any
number of candidates — if it ever looks cut off, they've drifted apart.

### Example: make the highlight taller

Add the same value to all three places, then reload with `fcitx5 -r -d`:

```ini
# highlight.svg
<rect ... height="44" ... rx="10" ry="10"  />
# theme.conf
[InputPanel/Highlight/Margin] Left=10 Right=10 Top=10 Bottom=10
[Menu/Highlight/Margin]       Left=10 Right=10 Top=10 Bottom=10
```

## Known Issues

- **SVG font-size misalignment**: the default highlight is an SVG tuned for
  14px text. After changing the system font size, the highlight block may no
  longer sit flush with the text until you re-tune `rx`/margins (see
  [Customization](#customization-diy)). If you don't care about perfect
  alignment, the shipped defaults still look fine.
- **Candidate positioning in Electron apps**: some XWayland apps (e.g.
  Chromium/Electron-based ones) report no preedit cursor, so the candidate
  window anchors to the top of the window instead of the caret. This is an
  upstream input-method quirk, not a theme bug.
- **Shadow on Wayland**: a drop shadow is baked into `panel.svg`, but Wayland
  doesn't extend the window, so the shadow only reads as an inner edge ring.

## Credits

- Packaging reference: [Debian Policy Manual](https://www.debian.org/doc/debian-policy/ch-binary.html), [Debian HowToPackage](https://wiki.debian.org/HowToPackageForDebian)
- Upstream: [fcitx5](https://github.com/fcitx/fcitx5), [fcitx5-rime](https://github.com/fcitx/fcitx5-rime), [fcitx5-gtk](https://github.com/fcitx/fcitx5-gtk), [fcitx5-qt](https://github.com/fcitx/fcitx5-qt), [fcitx5-chinese-addons](https://github.com/fcitx/fcitx5-chinese-addons)
- UI inspiration: [nobodysclown/rime-wechat-keyboard](https://github.com/nobodysclown/rime-wechat-keyboard), [rime-ice](https://github.com/iDvel/rime-ice)

## License

[MIT](LICENSE). Copyright (c) 2026.
