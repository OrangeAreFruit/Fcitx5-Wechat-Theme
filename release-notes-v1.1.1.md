# Release Notes — Fcitx5 WeChat Theme

**Tag / Release title:** `v1.1.1`

---

# Fcitx5 WeChat Theme v1.1.1

WeChat-style input method themes for Fcitx5, with a Rime memory patch and a prebuilt SVG-enabled fcitx5 (with rounded corners).

## Features

- **Two SVG vector themes**: `wechat-light` (light) and `wechat-dark` (dark)
- **True rounded corners**: SVG nine-patch rendering keeps the corner radius no matter how many candidates are shown
- **WeChat-aligned geometry**: outer radius 10px, highlight radius 8px, 4/6px inner padding, 14px candidate text
- **Rime memory patch**: speeds up dynamic frequency tuning so repeated words rise to the top
- **GNOME dark-mode switcher**: auto-switches between light/dark following the system color scheme

## Assets

Both files are required. Download and install them in order.

### 1. `fcitx5-svg-5.1.22-linux-x86_64.tar.gz`

Prebuilt SVG-enabled fcitx5 (>= 5.1.22, with librsvg support). **Ubuntu 26.04 users MUST install this to get rounded corners** — the distro ships fcitx5 5.1.19 without SVG support.

```bash
bash install-fcitx5-svg.sh ./fcitx5-svg-5.1.22-linux-x86_64.tar.gz
```

### 2. `fcitx5-wechat-theme_1.1.1_amd64.deb`

The WeChat theme installer.

```bash
sudo apt install ./fcitx5-wechat-theme_1.1.1_amd64.deb
```

> Full flow: install `fcitx5-svg` first (Step 1), then the `.deb` (Step 2). See the README for details.

## Notes

- Supports **Ubuntu 26.04 / x86_64** only (the prebuilt tarball is tied to the system libraries)
- On distros shipping fcitx5 >= 5.1.22 (Arch, Fedora, etc.), you can install just the `.deb`
- The theme is designed for 14px text; changing the font size requires re-rendering the SVGs per the DIY table in the README
- Source code is MIT-licensed

---

## Files to upload as Assets

- `fcitx5-wechat-theme_1.1.1_amd64.deb`
- `fcitx5-svg-5.1.22-linux-x86_64.tar.gz`
