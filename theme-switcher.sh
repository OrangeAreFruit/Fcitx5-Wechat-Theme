#!/usr/bin/env bash
# ============================================================
#  Fcitx5 明暗主题自动切换器（GNOME）
#  监听系统 color-scheme（浅色/深色），自动切换 wechat-light / wechat-dark
#  用法：
#    切换一次： bash theme-switcher.sh once
#    常驻监听： bash theme-switcher.sh            （推荐，建议作为自启动/服务）
# ============================================================
set -euo pipefail

CFG="$HOME/.config/fcitx5/conf/classicui.conf"
LIGHT="wechat-light"
DARK="wechat-dark"

log() { echo "[theme-switcher] $(date '+%H:%M:%S') $1"; }

apply() {
  local theme="$1"
  if [ -f "$CFG" ] && grep -q "^Theme=" "$CFG"; then
    # 已存在 Theme= 且不同才改写，避免无意义重启
    local cur
    cur="$(sed -n 's/^Theme=//p' "$CFG" | head -1)"
    if [ "$cur" = "$theme" ]; then
      log "主题已是 $theme，跳过"
      return
    fi
    sed -i "s/^Theme=.*/Theme=$theme/" "$CFG"
  else
    printf 'Theme=%s\n' "$theme" >> "$CFG"
  fi
  log "切换到 $theme"
  # 重启 fcitx5 使主题生效
  if pgrep -x fcitx5 >/dev/null 2>&1; then
    fcitx5 -r -d 2>/dev/null || true
  else
    nohup fcitx5 -d >/dev/null 2>&1 &
  fi
}

current_scheme() {
  # 返回 'dark' 或 'light'
  local s
  s="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
  case "$s" in
    prefer-dark) echo dark ;;
    *) echo light ;;
  esac
}

# ---------- 单次 ----------
if [ "${1:-}" = "once" ]; then
  [ "$(current_scheme)" = "dark" ] && apply "$DARK" || apply "$LIGHT"
  exit 0
fi

# ---------- 常驻监听 ----------
echo "开始监听 GNOME 明暗主题切换（Ctrl+C 退出）..."
# 先应用一次当前状态
[ "$(current_scheme)" = "dark" ] && apply "$DARK" || apply "$LIGHT"

gsettings monitor org.gnome.desktop.interface color-scheme | while read -r line; do
  log "检测到变化: $line"
  [ "$(current_scheme)" = "dark" ] && apply "$DARK" || apply "$LIGHT"
done
