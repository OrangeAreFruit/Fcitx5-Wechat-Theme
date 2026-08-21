#!/usr/bin/env bash
# 单实例启动面板：
#   - 进程存活且窗口在 -> 发唤醒信号，聚焦已存在的面板（不重复开）
#   - 进程不在         -> 启动新面板进程
# 基于脚本自身所在目录定位 webpanel.py，可随目录整体移动/解压到任意位置。
LOCK=/tmp/ime-panel.lock
WAKE=/tmp/ime-panel.wake
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 清理可能残留的旧唤醒信号
rm -f "$WAKE"

if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
  # 面板进程仍存活：写入唤醒信号，让已运行的面板把窗口重新带到前台，然后退出（不再多开）
  touch "$WAKE"
  exit 0
fi

# 锁中进程已死/无效：清理残留锁，重新启动面板
rm -f "$LOCK"
nohup /usr/bin/python3 "$SELF_DIR/webpanel.py" >/tmp/ime-panel.log 2>&1 &
echo $! > "$LOCK"
