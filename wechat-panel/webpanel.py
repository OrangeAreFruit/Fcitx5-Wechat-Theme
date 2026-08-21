#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fcitx5 微信风格设置面板 —— pywebview (WebKit2GTK) 版
前端: panel.html (HTML/CSS/JS 精致 UI)
后端: 读写 classicui.conf + 热重启 fcitx5

用法:  /usr/bin/python3 webpanel.py
"""
import os
import re
import sys
import time
import threading
import subprocess
from pathlib import Path

CFG = os.path.expanduser("~/.config/fcitx5/conf/classicui.conf")
HTML = os.path.join(os.path.dirname(os.path.abspath(__file__)), "panel.html")

# 主线程 QObject：把 startSystemMove 排队回主线程执行（js_api 在子线程跑）
_drag_helper = None


def _ensure_drag_helper():
    """在 Qt 主线程创建拖动帮助对象（QObject 必须在拥有事件循环的线程创建）。"""
    global _drag_helper
    if _drag_helper is not None:
        return
    try:
        from PyQt5 import QtCore

        class _QtDragHelper(QtCore.QObject):
            @QtCore.pyqtSlot()
            def do(self):
                try:
                    import webview
                    native = webview.windows[0].native  # QMainWindow
                    wnd = native.windowHandle()
                    if wnd is not None:
                        wnd.startSystemMove()
                except Exception:
                    pass

        _drag_helper = _QtDragHelper()
    except Exception:
        _drag_helper = None


def _conf_mtime():
    try:
        return os.path.getmtime(CFG)
    except OSError:
        return 0.0


def read_conf():
    size, theme = 14, "dark"
    if os.path.exists(CFG):
        with open(CFG, "r", encoding="utf-8") as f:
            c = f.read()
        m = re.search(r'Font\s*=\s*"(.*?)\s+(\d+)"', c)
        if m:
            try:
                size = int(m.group(2))
            except ValueError:
                pass
        m = re.search(r'^Theme\s*=\s*wechat-(\S+)', c, re.MULTILINE)
        if m:
            theme = m.group(1).strip()
    return size, theme


def write_conf(size, theme):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    c = ""
    if os.path.exists(CFG):
        with open(CFG, "r", encoding="utf-8") as f:
            c = f.read()
    name = "wechat-" + theme
    if re.search(r'^Font\s*=.*$', c, re.MULTILINE):
        c = re.sub(r'^Font\s*=.*$', 'Font="Noto Sans CJK SC %d"' % size, c, flags=re.MULTILINE)
    else:
        c += '\nFont="Noto Sans CJK SC %d"\n' % size
    if re.search(r'^Theme\s*=.*$', c, re.MULTILINE):
        c = re.sub(r'^Theme\s*=.*$', 'Theme=%s' % name, c, flags=re.MULTILINE)
    else:
        c += '\nTheme=%s\n' % name
    with open(CFG, "w", encoding="utf-8") as f:
        f.write(c)


def reload_classicui():
    """写配置后通知 fcitx5 即时重载 classicui（候选框立即应用主题/字号），不重启进程。

    通过 DBus 调用 org.fcitx.Fcitx.Controller1.ReloadAddonConfig("classicui")
    → 触发 classicui::reloadConfig → reloadTheme + 强制刷新所有候选框重绘，
    实现"切主题/字号即时生效"。
    """
    try:
        subprocess.run(
            [
                "dbus-send", "--session", "--dest=org.fcitx.Fcitx5",
                "--type=method_call", "--print-reply", "/controller",
                "org.fcitx.Fcitx.Controller1.ReloadAddonConfig",
                "string:classicui",
            ],
            check=False, timeout=5,
        )
    except FileNotFoundError:
        pass
    except Exception:
        pass


class Api:
    def __init__(self):
        self.size, self.theme = read_conf()
        self._last_mtime = _conf_mtime()

    def get_config(self):
        """前端打开时读取一次当前配置"""
        return {"theme": self.theme, "font": self.size}

    def set_theme(self, theme):
        self.theme = theme
        write_conf(self.size, theme)
        reload_classicui()

    def set_font(self, size):
        psize = max(12, min(28, int(size)))
        self.size = psize
        write_conf(psize, self.theme)
        reload_classicui()

    def close(self):
        import webview
        LOCK = "/tmp/ime-panel.lock"
        try:
            webview.windows[0].destroy()
        except Exception:
            pass
        # 删除单实例锁，避免"关掉后无法再唤起"：锁遗留会让 run-panel.sh 误判为已运行
        try:
            if os.path.exists(LOCK):
                os.remove(LOCK)
        except Exception:
            pass
        # 销毁窗口后进程本应结束；Qt 后端事件循环不一定会退出，这里强制结束，
        # 保证下次点击绿圆环时锁文件已清、能正常重新启动面板。
        os._exit(0)

    def move_win(self, x, y):
        """前端顶栏拖动：把窗口移动到 (x, y)"""
        import webview
        try:
            webview.windows[0].move(int(x), int(y))
        except Exception:
            pass

    def start_drag(self):
        """启动 Qt 原生交互式移动（Wayland 支持）。

        pywebview 的 js_api 方法在子线程执行，而 QWindow::startSystemMove()
        必须在主线程调用，所以通过 QMetaObject.invokeMethod 排队回主线程执行。
        """
        try:
            from PyQt5 import QtCore
            if _drag_helper is not None:
                QtCore.QMetaObject.invokeMethod(
                    _drag_helper, "do", QtCore.Qt.QueuedConnection
                )
        except Exception:
            pass


def _screen_size():
    """获取屏幕物理分辨率(考虑DPI缩放)，返回 (w, h)"""
    try:
        import gi
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gdk
        display = Gdk.Display.get_default()
        if display is not None:
            mon = display.get_primary_monitor()
            if mon is None:
                # 退回到第一个显示器
                mon = display.get_monitor(0) if display.get_n_monitors() > 0 else None
            if mon is not None:
                geo = mon.get_geometry()
                scale = mon.get_scale_factor()
                return geo.width * scale, geo.height * scale
    except Exception:
        pass
    return 1920, 1080


def _panel_size():
    """按分辨率动态计算面板尺寸：取屏幕较短边的一定比例，保证各种分辨率都合适"""
    sw, sh = _screen_size()
    # 以较小边为基准：小屏取大比例，大屏取小比例，让面板始终适中
    base = min(sw, sh)
    width = int(base * 0.30)          # 宽约为短边的 30%
    height = int(base * 0.32)         # 高约为短边的 32%
    # 设下限和上限，避免过小或过大
    width = max(300, min(430, width))
    height = max(320, min(520, height))
    return width, height


def _center_pos(width, height):
    """计算窗口居中位置 (x, y)"""
    sw, sh = _screen_size()
    return max(0, (sw - width) // 2), max(0, (sh - height) // 2)


def _watch_wake():
    """单实例唤醒监听：run-panel.sh 判定面板已存活时会写入 /tmp/ime-panel.wake，
    这里检测到后把已存在的窗口重新带到前台，实现“第二次点击只唤醒、不多开”"""
    import webview
    WAKE = "/tmp/ime-panel.wake"
    win = None
    while True:
        time.sleep(0.3)
        if win is None:
            try:
                win = webview.windows[0]
                win.events.shown.wait(10)  # 等待窗口真正显示后再处理唤醒
            except Exception:
                continue  # 窗口尚未就绪，稍后再试
        if os.path.exists(WAKE):
            try:
                os.remove(WAKE)
                # 窗口创建时已 on_top=True（永久置顶），唤醒只需显示/恢复
                win.show()          # 重新显示窗口
                win.restore()       # 若被最小化，恢复
            except Exception:
                pass


def _watch_conf_push(api):
    """监听 classicui.conf：文件被外部修改时，读取新值并通过 JS 同步到前端。

    这样面板打开期间，即使配置是候选框/其他地方改的（或面板 bot 打开时被改），
    界面也会保持最新；同时面板打开时 get_config() 也已读取一次，双保险。
    """
    import json
    import webview
    while True:
        time.sleep(0.8)
        mt = _conf_mtime()
        if mt and mt != api._last_mtime:
            api._last_mtime = mt
            api.size, api.theme = read_conf()
            try:
                webview.windows[0].evaluate_js(
                    "window.pywebviewPushConfig && window.pywebviewPushConfig(%s)"
                    % json.dumps({"theme": api.theme, "font": api.size})
                )
            except Exception:
                pass


def main():
    import webview
    api = Api()
    width, height = _panel_size()
    x, y = _center_pos(width, height)
    w = webview.create_window(
        "IME Settings", HTML, js_api=api,
        width=width, height=height, x=x, y=y, resizable=False, frameless=True,
        easy_drag=False, transparent=True, on_top=True,
    )
    # QtWebEngine(Qt) 后端支持真透明窗口，配合 body 透明背景实现"悬浮圆角卡片"，
    # 窗口四周无白底，视觉上与微信输入法一致。
    # 若未安装 python3-pyqt5.qtwebengine，会回退到 GTK(WebKit2) 后端(不支持真透明)。
    # 启动单实例唤醒监听：第二次点击绿圆环时只唤醒、不多开面板
    _ensure_drag_helper()
    threading.Thread(target=_watch_wake, daemon=True).start()
    # 配置文件变化推送到前端（外部修改也能实时同步界面）
    threading.Thread(target=_watch_conf_push, args=(api,), daemon=True).start()
    webview.start(gui="qt")


if __name__ == "__main__":
    main()
