#!/usr/bin/env bash
# ============================================================
#  Fcitx5 + Rime(K雾凇拼音) + 微信主题 · 一键安装脚本
#
#  目标：让任何一台 Ubuntu (x86_64) 从零到一，只需一条命令
#  就能得到一套「干净、只有雾凇拼音、带微信皮肤」的输入法环境。
#
#  用法：  sudo bash install-all.sh
#
#  内容：  1) 彻底移除系统上所有输入法体系(fcitx/ibus/pecita 等)
#          2) 安装依赖(含 classicui 所需的 libxcb-ewmh2 / librsvg / librime)
#          3) 部署随包的自编译 fcitx5 (SVG 版 5.1.22)
#          4) 安装雾凇拼音(rime-ice) 词库(本地 packages/rime-ice)
#          5) 安装 wechat-light / wechat-dark 主题
#          6) 配置经典 UI: 只启用 rime, 默认中文, 启用主题
#          7) 重启 fcitx5
# ============================================================
set -euo pipefail

# ---------- 颜色 ----------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$SCRIPT_DIR/packages"

# ---------- 权限检查 ----------
if [ "$(id -u)" -ne 0 ]; then
  err "请用 sudo 运行:  sudo bash install-all.sh"
  exit 1
fi
HUSER="${SUDO_USER:-${USER:-$(id -un)}}"
HHOME="$(getent passwd "$HUSER" | cut -d: -f6)"
[ -n "$HHOME" ] || HHOME="/root"

info "目标用户: $HUSER  家目录: $HHOME"

# ---------- 前置完整性检查 ----------
[ -f "$PKG/fcitx5-svg-5.1.22-linux-x86_64.tar.gz" ] || { err "缺少 packages/fcitx5-svg-5.1.22-linux-x86_64.tar.gz"; exit 1; }
[ -d "$PKG/rime-ice" ]   || { err "缺少 packages/rime-ice/ 词库目录"; exit 1; }
[ -d "$PKG/themes/wechat-dark" ] || { err "缺少 packages/themes/"; exit 1; }

# ============================================================
# 第 1 步：彻底移除系统上所有输入法体系
# ============================================================
echo; echo "===== [1/7] 移除现有输入法体系 ====="
# 停掉正在跑的输入法
for p in fcitx fcitx5 ibus-daemon; do
  pkill -f "$p" 2>/dev/null || true
done
sleep 1

# 清理 fcitx / fcitx5 / ibus / 各种输入法引擎(保留系统必需的非输入法组件)
# 注意：绝不触碰 fcitx5、librime、librsvg 相关(它们正是我们要的)，
#       但需把可能冲突的拼音引擎/ibus/fcitx4 清理干净。
apt-get purge -y -qq \
  ibus ibus-gtk3 ibus-gtk4 ibus-table fcitx fcitx-bin fcitx-config-common \
  fcitx-config-gtk fcitx-table-* \
  fcitx5-pinyin fcitx5-chinese-addons fcitx5-table fcitx5-chewing \
  fcitx5-hangul fcitx5-unikey fcitx5-anthy \
  libpinyin* libime* 2>/dev/null || true

# 清理可能残留的配置目录(只在迁移到全新环境时执行)
if [ -d "$HHOME/.config/fcitx" ]; then
  mv "$HHOME/.config/fcitx" "$HHOME/.config/fcitx.bak.$(date +%s)" 2>/dev/null || true
fi
info "旧输入法体系已清理(将保留 fcitx5 / librime / rsvg)"

echo; echo "===== [2/7] 安装系统依赖 ====="
apt-get update -qq
# 关键:libxcb-ewmh2 是 classicui(SVG皮肤)的硬依赖,缺失会导致皮肤不显示(仅打字正常)
apt-get install -y -qq \
  libxcb-ewmh2 libxcb-imdkit1 libxkbcommon0 \
  librsvg2-2 librsvg2-common \
  librime1t64 librime-bin librime-dev \
  libfcitx5config6 libfcitx5utils2 libfmt10 \
  2>/dev/null || { warn "部分依赖安装失败，请检查 apt 源"; }

# ============================================================
# 第 2 步：部署自编译的 SVG 版 fcitx5 (5.1.22)
# ============================================================
echo; echo "===== [3/7] 部署自编译 fcitx5-SVG (5.1.22) ====="
TMP="$(mktemp -d)"
tar -xzf "$PKG/fcitx5-svg-5.1.22-linux-x86_64.tar.gz" -C "$TMP"
cp -a "$TMP/usr/bin"/*        /usr/bin/
cp -a "$TMP/usr/lib/x86_64-linux-gnu/." /usr/lib/x86_64-linux-gnu/
cp -a "$TMP/usr/share/fcitx5/." /usr/share/fcitx5/
rm -rf "$TMP"
ldconfig
info "fcitx5 5.1.22 (SVG) 已部署"
# 验证 SVG support
if ldd /usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so 2>/dev/null | grep -qi librsvg; then
  info "已确认 classicui 带 librsvg —— SVG 圆角皮肤将正常渲染"
else
  warn "classicui 未检测到 librsvg，皮肤圆角可能退化(不影响打字)"
fi

# ============================================================
# 第 3 步：安装雾凇拼音词库 (本地 packages/rime-ice)
# ============================================================
echo; echo "===== [4/7] 安装雾凇拼音(rime-ice)词库 ====="
RIME_DIR="$HHOME/.local/share/fcitx5/rime"
mkdir -p "$RIME_DIR"
# 覆盖式安装源码词库(保留用户已有的 userdb/build,仅补充/覆盖词典)
cp -a "$PKG/rime-ice/." "$RIME_DIR/"
# 写入安装信息
cat > "$RIME_DIR/installation.yaml" <<EOF
distribution_code: fcitx5
distribution_name: Rime
distribution_version: 5.1.22
install_time: "$(date +%s)"
EOF
[ -f "$PKG/rime_ice.custom.yaml" ] && cp -f "$PKG/rime_ice.custom.yaml" "$RIME_DIR/"
info "雾凇拼音词库已安装到 $RIME_DIR"

# ============================================================
# 第 4 步：安装微信主题
# ============================================================
echo; echo "===== [5/7] 安装微信主题 ====="
THEME_DIR="$HHOME/.local/share/fcitx5/themes"
mkdir -p "$THEME_DIR"
cp -r "$PKG/themes/wechat-light" "$THEME_DIR/"
cp -r "$PKG/themes/wechat-dark"  "$THEME_DIR/"
info "已安装 wechat-light / wechat-dark 主题"

# ============================================================
# 第 5 步：配置经典 UI —— 只启用 rime
# ============================================================
echo; echo "===== [6/7] 配置 fcitx5(只启用雾凇拼音) ====="
CFG_DIR="$HHOME/.config/fcitx5"
mkdir -p "$CFG_DIR/conf"

# 5.1 经典 UI 主题
cat > "$CFG_DIR/conf/classicui.conf" <<'EOF'
# Fcitx5 经典UI(候选框)配置 —— 微信风格
Font="Noto Sans CJK SC 14"
Theme=wechat-light
PerScreenDPI=False
EOF

# 5.2 输入法列表：只保留 rime(雾凇拼音)—— 输入法设置里唯一可用项
cat > "$CFG_DIR/profile" <<'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=rime
# Layout

[GroupOrder]
0=Default
EOF

# 5.3 声明只启用 rime 引擎, 并默认开启中文(ActiveByDefault=True)
cat > "$CFG_DIR/config" <<'EOF'
[Behavior]
ActiveByDefault=True
ShareInputState=No
PreeditEnabledByDefault=True
DefaultPageSize=5
EOF

chown -R "$HUSER":"$(id -gn "$HUSER")" "$HHOME/.config/fcitx5" "$HHOME/.local/share/fcitx5" 2>/dev/null || true
info "已配置：输入法仅保留 rime(雾凇拼音)，主题 wechat-light"

# ============================================================
# 第 6 步：启动 fcitx5
# ============================================================
echo; echo "===== [7/7] 启动 fcitx5 ====="
if pgrep -x fcitx5 >/dev/null 2>&1; then
  pkill -x fcitx5 2>/dev/null || true
  sleep 1
fi
# 以用户身份启动(不要用 root)
sudo -u "$HUSER" env DISPLAY="${DISPLAY:-:0}" XDG_RUNTIME_DIR="/run/user/$(id -u "$HUSER")" \
  nohup fcitx5 -d >/dev/null 2>&1 &
sleep 3

if pgrep -x fcitx5 >/dev/null 2>&1; then
  info "fcitx5 已启动 (PID $(pgrep -x fcitx5))"
else
  warn "fcitx5 未自动启动，请注销重新登录，或手动运行: fcitx5 -d"
fi

echo
echo "=========================================================="
info "安装完成！"
echo "  - 输入法框架:  fcitx5 5.1.22 (SVG圆角)"
echo "  - 输入法:      仅有 雾凇拼音 (rime-ice)"
echo "  - 主题:        wechat-light (切深色改 classicui.conf 为 wechat-dark)"
echo "  - 切换输入法:  默认键盘(英文) / 雾凇拼音"
echo "  - 建议:        注销重新登录一次，让环境变量彻底生效"
echo "=========================================================="
