#!/usr/bin/env bash
# ============================================================
#  Install the prebuilt fcitx5 (SVG build, Ubuntu 26.04 x86_64)
#
#  Usage:
#    bash install-fcitx5-svg.sh [path/to/fcitx5-svg-5.1.22-linux-x86_64.tar.gz]
#
#  Steps: check deps -> extract -> copy to /usr -> ldconfig
#  Then install the theme .deb:
#    sudo apt install ./fcitx5-wechat-theme_1.1.1_amd64.deb
# ============================================================
set -euo pipefail

info(){ echo -e "\033[0;32m[✓]\033[0m $1"; }
warn(){ echo -e "\033[0;33m[!]\033[0m $1"; }
err(){ echo -e "\033[0;31m[✗]\033[0m $1"; }

# ----- locate the tarball -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TGZ="${1:-}"
if [ -z "$TGZ" ]; then
  TGZ="$(ls "$SCRIPT_DIR"/dist/fcitx5-svg-*.tar.gz 2>/dev/null | head -1 || true)"
fi
[ -n "$TGZ" ] && [ -f "$TGZ" ] || { err "未找到 fcitx5-svg tar.gz，请通过参数指定，如：bash install-fcitx5-svg.sh ./fcitx5-svg-5.1.22-linux-x86_64.tar.gz"; exit 1; }

# ----- 1. OS check -----
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  warn "仅针对 Ubuntu 测试过。其他发行版请自行确认。/etc/os-release 未识别为 Ubuntu。"
fi
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
[ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || { err "此包仅为 x86_64 构建（当前: $ARCH）。"; exit 1; }

# ----- 2. apt dependencies -----
warn "需要以 root 权限安装依赖并写入 /usr。请输入 sudo 密码（如账户有权限）。"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  librsvg2-2 librsvg2-common \
  librime1t64 librime-bin libfcitx5config6 libfcitx5core7 libfcitx5utils2 \
  libxcb-imdkit0 libxkbcommon0 libfmt10 || true
info "已更新系统依赖（librsvg / librime 等）"

# ----- 3. extract & copy -----
TMP="$(mktemp -d)"
tar -xzf "$TGZ" -C "$TMP"
info "已解压"

sudo cp -a "$TMP/usr/bin"/*        /usr/bin/
sudo cp -a "$TMP/usr/lib/x86_64-linux-gnu/." /usr/lib/x86_64-linux-gnu/
sudo cp -a "$TMP/usr/share/fcitx5/." /usr/share/fcitx5/
rm -rf "$TMP"
info "已复制文件到 /usr"

# ----- 4. refresh cache & permissions -----
sudo ldconfig
info "已运行 ldconfig"

echo
info "fcitx5 SVG 构建已安装。验证："
echo "    ldd /usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so | grep librsvg   # 应看到 librsvg"
echo
echo "下一步安装微信主题："
echo "    sudo apt install ./fcitx5-wechat-theme_1.1.1_amd64.deb"
echo "然后重新登录，或运行:  fcitx5 -r -d"
