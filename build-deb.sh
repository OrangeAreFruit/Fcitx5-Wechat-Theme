#!/usr/bin/env bash
# ============================================================
#  构建 fcitx5-wechat-theme 的 .deb 安装包
#  用法：bash build-deb.sh
#  产出：dist/fcitx5-wechat-theme_<version>_amd64.deb
# ============================================================
set -euo pipefail

PACKAGE="fcitx5-wechat-theme"
VERSION="1.1.1"
ARCH="amd64"
MAINTAINER="rime-ice theme maintainers <maintainer@example.com>"
DESC="Fcitx5 WeChat-style IME themes (light/dark) + rime-ice memory patch"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
STAGE="$ROOT/build/deb-stage"
DIST="$ROOT/dist"

info() { echo -e "\033[0;32m[✓]\033[0m $1"; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN"
mkdir -p "$STAGE/usr/share/fcitx5/themes/wechat-light"
mkdir -p "$STAGE/usr/share/fcitx5/themes/wechat-dark"
mkdir -p "$STAGE/usr/share/$PACKAGE"

# ---------- 复制主题到系统路径 ----------
cp "$ROOT/fcitx5/themes/wechat-light/theme.conf"  "$STAGE/usr/share/fcitx5/themes/wechat-light/"
cp "$ROOT/fcitx5/themes/wechat-light/panel.svg"   "$STAGE/usr/share/fcitx5/themes/wechat-light/"
cp "$ROOT/fcitx5/themes/wechat-light/highlight.svg" "$STAGE/usr/share/fcitx5/themes/wechat-light/"
cp "$ROOT/fcitx5/themes/wechat-dark/theme.conf"   "$STAGE/usr/share/fcitx5/themes/wechat-dark/"
cp "$ROOT/fcitx5/themes/wechat-dark/panel.svg"    "$STAGE/usr/share/fcitx5/themes/wechat-dark/"
cp "$ROOT/fcitx5/themes/wechat-dark/highlight.svg" "$STAGE/usr/share/fcitx5/themes/wechat-dark/"

# ---------- 附带资源（rime 记忆补丁 + 参考说明） ----------
cp "$ROOT/fcitx5/rime_ice.custom.yaml" "$STAGE/usr/share/$PACKAGE/"
cp "$ROOT/theme-switcher.sh"           "$STAGE/usr/share/$PACKAGE/"

# ---------- control ----------
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $(du -sk "$STAGE" | cut -f1)
Depends: fcitx5
Suggests: librsvg2-2, fcitx5-rime
Description: $DESC
 Fcitx5 WeChat-style input method themes.
 .
 Includes two SVG vector themes (wechat-light / wechat-dark) with
 large rounded corners using nine-patch stretching, plus an optional
 rime-ice memory/frequency patch and a GNOME dark-mode auto switcher.
 .
 Full vector rounded corners require fcitx5 >= 5.1.22 built with
 librsvg support (see repository README for building from source).
 On distro fcitx5 (e.g. Ubuntu 26.04, 5.1.19) the themes still install
 but corners fall back to rectangles.
EOF

# ---------- postinst：写入 classicui.conf 并提示 ----------
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
CFG="$HOME/.config/fcitx5/conf/classicui.conf"
mkdir -p "$(dirname "$CFG")"
touch "$CFG"
if ! grep -q "^Theme=" "$CFG"; then
    printf 'Theme=wechat-light\n' >> "$CFG"
fi
# 尝试把记忆补丁同步到用户 rime 目录（存在则覆盖）
RIME_DIR="$HOME/.local/share/fcitx5/rime"
if [ -d "$RIME_DIR" ] && [ -f "/usr/share/fcitx5-wechat-theme/rime_ice.custom.yaml" ]; then
    cp "/usr/share/fcitx5-wechat-theme/rime_ice.custom.yaml" "$RIME_DIR/" 2>/dev/null || true
fi
if command -v fcitx5 >/dev/null 2>&1; then
    fcitx5 -r -d 2>/dev/null >/dev/null &
fi
echo "fcitx5-wechat-theme installed. Theme=wechat-light (edit classicui.conf to switch)."
exit 0
EOF
chmod 755 "$STAGE/DEBIAN/postinst"

# ---------- 打包 ----------
mkdir -p "$DIST"
DEBFILE="$DIST/${PACKAGE}_${VERSION}_${ARCH}.deb"
fakeroot dpkg-deb --build "$STAGE" "$DEBFILE"
rm -rf "$STAGE"
info "已生成：$DEBFILE"
dpkg-deb --info "$DEBFILE" | head -20
