# Fcitx5 WeChat Theme

WeChat-style input method for [Fcitx5](https://github.com/fcitx/fcitx5), with
**patch modules** (candidate-window gear button, tray icon/menu), **Web settings
panel** (transparent rounded card), a rime-ice layout, and a one-click install
script validated in Docker.

![Light](screenshots/light-mode-exam.png) ![Dark](screenshots/dark-mode-exam.png)

> **⚠️ Before you start — know the two ways to use this theme.**
>
> - **Just want to try it** (no tweaking): run the install commands below and it works out of the box.
> - **Want pixel-perfect results after changing the font size / margins**: this theme uses **SVG-based highlight blocks**. The SVGs are tuned for **14px text** (see [Customization](#customization-diy)); if you bump the system font size without adjusting the SVG `rx`/margins, the highlight roundness breaks. Beginners should treat the shipped defaults as the recommended baseline and only tweak via the guide below.

## New in this branch

- **Candidate-window gear button** (classicui patch): a green ring button at the
  bottom-right of the candidate window; click it to open the **Web settings
  panel** (font size / light-dark theme). Hover shows a light-blue rounded
  backdrop. Right-click the candidate window for a quick menu.
- **Theme / font changes apply instantly** (classicui patch): the candidate
  window watches `~/.config/fcitx5/conf/classicui.conf` and repaints on change —
  no `fcitx5 -r` needed.
- **Custom tray icon** (notificationitem patch): fixed `fcitx-wusong` icon
  (green rounded square + sprout), sent as real pixmap data; tray menu is
  reduced to **Preference** (opens the settings panel) + **Restart**.
- **Web settings panel** (`wechat-panel/`): pywebview + QtWebEngine, fully
  transparent rounded card pinned on top (WeChat-style), slider font size,
  light/dark theme cards with preview, instant apply, single-instance wake-up,
  drag by the title bar.
- **One-click installer** `install-new.sh` for a clean Ubuntu/Debian x86_64:
  deploys the prebuilt SVG fcitx5 + patch modules, themes, rime-ice (keeps your
  existing rime userdb/build), tray icon, panel autostart — and **never deletes
  user data**; every overwritten system file is backed up to
  `/root/fcitx5-backup-<ts>/`. Validated in an Ubuntu 26.04 Docker container.

## Requirements

SVG rendering needs fcitx5 classicui built with librsvg:

- fcitx5 **>= 5.1.22** (distro builds here).
- Ubuntu 26.04 ships fcitx5 **5.1.19** without SVG support — the tar.gz bundles
  a self-built 5.1.22 with the patches, see [Installation](#installation).

## Installation

### One-click install (recommended) — `install-new.sh`

Download this repo (git clone, or unpack the release tarball), then from the
repo root:

```bash
sudo bash install-new.sh
```

The script (idempotent, no user data removed):

1. Installs missing system libraries (librsvg, xcb, librime, …).
2. Deploys the bundled prebuilt **SVG fcitx5 5.1.22** from `packages/`
   (includes the classicui + notificationitem patches).
3. Installs `wechat-light` / `wechat-dark` themes (user-level).
4. Installs the **rime-ice (雾凇拼音)** dictionary — keeps existing `userdb/`,
   `build/`, user configs; only backs up overwritten files.
5. Configures fcitx5: Rime enabled, Chinese by default, `Theme=wechat-light`.
6. Installs the Web settings panel to `/opt/fcitx5-wechat-panel` (+ autostart).
7. Installs the custom tray icon + autostart entries.
8. Restarts fcitx5.

Log out & back in once so the input-method environment variables take effect.

> **Where the panel lives:** the panel is installed to `/opt/fcitx5-wechat-panel`.
> Because the prebuilt patch modules launch it via `$HOME/fcitx5-wechat-panel/run-panel.sh`
> (gear button & tray Preference), the installer also creates the symlink
> `~/fcitx5-wechat-panel → /opt/fcitx5-wechat-panel` so both entry points work on
> any machine out of the box.

### Step 1 — Install the prebuilt SVG fcitx5 (manual, Ubuntu 26.04 / x86_64)

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
├── install-new.sh          # ★ Recommended one-click installer (8 steps, no data loss)
├── install.sh              # User-level installer (themes + rime patch)
├── install-all.sh          # Legacy one-click full environment installer (7 steps)
├── install-fcitx5-svg.sh   # Installs the prebuilt SVG fcitx5 tarball (manual step 1)
├── build-deb.sh            # Builds the .deb package
├── package-fcitx5.sh       # Builds the fcitx5-svg tarball (also from a PATCH_DIR)
├── theme-switcher.sh       # GNOME dark-mode auto switcher
├── packages/               # Bundled offline assets used by the installers
│   ├── fcitx5-svg-5.1.22-linux-x86_64.tar.gz   # prebuilt SVG fcitx5 + patch modules
│   ├── rime-ice/           # rime-ice (雾凇拼音) dictionary
│   └── themes/             # wechat-light / wechat-dark (legacy)
├── wechat-panel/           # Web settings panel → installed to /opt/fcitx5-wechat-panel
│   ├── webpanel.py         # pywebview + QtWebEngine transparent app
│   ├── panel.html          # panel UI (font slider, light/dark cards)
│   ├── run-panel.sh        # single-instance launcher
│   └── ime-panel.desktop   # panel desktop entry (path: /opt/fcitx5-wechat-panel)
├── icons/                  # custom tray icon (fcitx-wusong.svg + 16–128 PNGs)
├── src/fcitx5-patches/     #覆盖式源码补丁 (classicui / notificationitem) for self-build
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
