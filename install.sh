#!/usr/bin/env bash
# ============================================================
#  Fcitx5 微信输入法风格 · 一键安装脚本
#  适用：GNOME / 其他桌面上的 Fcitx5（含源码编译的 5.1.22+ 版本）
#  内容：两套微信风格 SVG 主题 + 雾凇拼音记忆调频补丁
#  用法：bash install.sh
# ============================================================
set -euo pipefail

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 前置检查 ----------
if ! command -v fcitx5 >/dev/null 2>&1; then
  err "未检测到 fcitx5。请先安装 Fcitx5（apt install fcitx5 或源码编译）。
   提示：SVG 矢量圆角主题需要 fcitx5 ≥ 5.1.22 且 classicui 带 librsvg 支持。"
  exit 1
fi
info "检测到 fcitx5：$(fcitx5 --version 2>/dev/null || echo 未知)"

# 检测 classicui 是否带 librsvg（决定 SVG 圆角能否生效）
FCITX5_ADDON_DIR=""
for d in /usr/lib/x86_64-linux-gnu/fcitx5 /usr/lib64/fcitx5 /usr/lib/fcitx5; do
  if [ -f "$d/libclassicui.so" ]; then FCITX5_ADDON_DIR="$d"; break; fi
done
SVG_OK=0
if [ -n "$FCITX5_ADDON_DIR" ] && ldd "$FCITX5_ADDON_DIR/libclassicui.so" 2>/dev/null | grep -qi librsvg; then
  SVG_OK=1
fi
if [ "$SVG_OK" = "1" ]; then
  info "已检测到 librsvg 支持，SVG 矢量大圆角可正常渲染。"
else
  warn "当前 fcitx5 的 classicui 可能不支持 SVG 渲染。
   此主题需要 fcitx5 ≥ 5.1.22 并编译时启用 librsvg（参见 README 的「从源码编译」说明）。
   仍会复制主题，但圆角可能退化为直角/矩形。"
fi

# ---------- 备份 ----------
CFG_DIR="$HOME/.config/fcitx5"
THEME_DIR="$HOME/.local/share/fcitx5/themes"
RIME_DIR="$HOME/.local/share/fcitx5/rime"
mkdir -p "$THEME_DIR" "$RIME_DIR"
[ -f "$CFG_DIR/conf/classicui.conf" ] && cp "$CFG_DIR/conf/classicui.conf" "$CFG_DIR/conf/classicui.conf.bak" && info "已备份 classicui.conf"

# ---------- 安装主题 ----------
cp -r "$SCRIPT_DIR/fcitx5/themes/wechat-light" "$THEME_DIR/"
cp -r "$SCRIPT_DIR/fcitx5/themes/wechat-dark"  "$THEME_DIR/"
info "已安装两套主题：wechat-light / wechat-dark"

# ---------- 安装雾凇记忆补丁 ----------
if [ -f "$SCRIPT_DIR/fcitx5/rime_ice.custom.yaml" ]; then
  cp "$SCRIPT_DIR/fcitx5/rime_ice.custom.yaml" "$RIME_DIR/"
  info "已安装雾凇拼音记忆调频补丁 rime_ice.custom.yaml"
else
  warn "未找到 rime_ice.custom.yaml，跳过记忆补丁。"
fi

# ---------- 启用浅色主题 ----------
mkdir -p "$CFG_DIR/conf"
if [ -f "$CFG_DIR/conf/classicui.conf" ] && grep -q "^Theme=" "$CFG_DIR/conf/classicui.conf"; then
  sed -i 's/^Theme=.*/Theme=wechat-light/' "$CFG_DIR/conf/classicui.conf"
else
  # 保留原内容，追加/补全 Theme 行
  touch "$CFG_DIR/conf/classicui.conf"
  grep -q "^\s*Theme=" "$CFG_DIR/conf/classicui.conf" || printf 'Theme=wechat-light\n' >> "$CFG_DIR/conf/classicui.conf"
fi
info "已将 Fcitx5 主题设为 wechat-light（可在 classicui.conf 改为 wechat-dark 切换深色）"

# ---------- 重启 fcitx5 ----------
if pgrep -x fcitx5 >/dev/null 2>&1; then
  fcitx5 -r -d 2>/dev/null
  sleep 1
  info "已重启 fcitx5。"
else
  nohup fcitx5 -d >/dev/null 2>&1 &
  info "已启动 fcitx5。"
fi

echo
info "安装完成！切换输入法皮肤到 wechat-light / wechat-dark："
echo "   在 Fcitx5 配置 -> 外观 中，或编辑 ~/.config/fcitx5/conf/classicui.conf"
echo "   若切换后未立即生效，请注销重新登录一次。"
