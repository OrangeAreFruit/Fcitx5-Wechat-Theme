#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fcitx5 WeChat 风格输入法设置面板
=================================
功能：调字体大小、切浅色/深色皮肤、实时生效（写 classicui.conf + 热重启 fcitx5）
技术：Python 3 (tkinter) —— 零额外依赖，开箱即用。

用法：
    python3 ime_panel.py          # 打开设置面板
"""
import os
import re
import sys
import subprocess
import tkinter as tk
from tkinter import ttk

CFG_PATH = os.path.expanduser("~/.config/fcitx5/conf/classicui.conf")
LIGHT = "wechat-light"
DARK = "wechat-dark"

# 微信风格配色
WE = {
    "light": {
        "bg": "#F7F7F7", "card": "#FFFFFF", "fg": "#111111",
        "sub": "#888888", "accent": "#07C160", "accent_fg": "#FFFFFF",
        "border": "#E8E8E8", "preview_bg": "#F2F2F2",
    },
    "dark": {
        "bg": "#1F1F1F", "card": "#2A2A2A", "fg": "#F0F0F0",
        "sub": "#9A9A9A", "accent": "#07C160", "accent_fg": "#FFFFFF",
        "border": "#3A3A3A", "preview_bg": "#232323",
    },
}


def read_conf():
    """读取 classicui.conf，返回 Font 字号和 Theme"""
    font_size = 14
    theme = LIGHT
    if os.path.exists(CFG_PATH):
        with open(CFG_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        m = re.search(r'Font\s*=\s*"(.*?)\s+(\d+)"', content)
        if m:
            try:
                font_size = int(m.group(2))
            except ValueError:
                pass
        m = re.search(r'^Theme\s*=\s*(\S+)', content, re.MULTILINE)
        if m:
            theme = m.group(1).strip()
    return font_size, theme


def write_conf(font_size, theme):
    """写回 classicui.conf，仅替换 Font 与 Theme 两行，保留其余内容"""
    os.makedirs(os.path.dirname(CFG_PATH), exist_ok=True)
    content = ""
    if os.path.exists(CFG_PATH):
        with open(CFG_PATH, "r", encoding="utf-8") as f:
            content = f.read()
    # 替换 Font 行
    if re.search(r'^Font\s*=.*$', content, re.MULTILINE):
        content = re.sub(r'^Font\s*=.*$',
                         'Font="Noto Sans CJK SC %d"' % font_size,
                         content, flags=re.MULTILINE)
    else:
        content += '\nFont="Noto Sans CJK SC %d"\n' % font_size
    # 替换 Theme 行
    if re.search(r'^Theme\s*=.*$', content, re.MULTILINE):
        content = re.sub(r'^Theme\s*=.*$', 'Theme=%s' % theme,
                         content, flags=re.MULTILINE)
    else:
        content += '\nTheme=%s\n' % theme
    with open(CFG_PATH, "w", encoding="utf-8") as f:
        f.write(content)


def restart_fcitx():
    """热重启 fcitx5，使改动立即生效"""
    try:
        subprocess.run(["fcitx5-remote", "-r"], check=False, timeout=5)
        return
    except FileNotFoundError:
        pass
    # 兜底：直接重启进程
    subprocess.run(["pkill", "-x", "fcitx5"], check=False)
    subprocess.Popen(["fcitx5", "-d"], start_new_session=True)


class ImePanel(tk.Tk):
    def __init__(self):
        super().__init__()
        self.font_size, self.theme = read_conf()
        self.title("IME Settings")
        self.attributes("-topmost", True)    # 置顶
        self.configure(bg=WE["light"]["bg"])

        self._apply_theme(self.theme == DARK)
        self._build_ui()
        self._center_on_screen()

    def _center_on_screen(self):
        """按屏幕 60% 尺寸，水平垂直居中显示"""
        self.update_idletasks()
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        w = int(sw * 0.60)
        h = int(sh * 0.60)
        x = (sw - w) // 2
        y = (sh - h) // 2
        self.geometry("%dx%d+%d+%d" % (w, h, x, y))
        self.minsize(int(sw * 0.4), int(sh * 0.4))

    # ---------- 配色 ----------
    def _apply_theme(self, dark):
        self.dark = dark
        self.c = WE["dark"] if dark else WE["light"]
        self.configure(bg=self.c["bg"])

    # ---------- UI ----------
    def _build_ui(self):
        F = "Sans"
        body = tk.Frame(self, bg=self.c["bg"])
        body.pack(fill="both", expand=True, padx=6, pady=6)

        # 标题栏
        head = tk.Frame(body, bg=self.c["card"], highlightthickness=0)
        head.pack(fill="x")
        tk.Label(head, text="IME Settings", bg=self.c["card"],
                 fg=self.c["fg"], font=(F, 20, "bold")).pack(
            side="left", padx=24, pady=22)
        close = tk.Label(head, text="✕", bg=self.c["card"], fg=self.c["sub"],
                         font=(F, 18), cursor="hand2")
        close.pack(side="right", padx=24)
        close.bind("<Button-1>", lambda _: self.destroy())

        card = tk.Frame(body, bg=self.c["card"], highlightbackground=self.c["border"],
                        highlightthickness=1)
        card.pack(fill="both", expand=True, padx=14, pady=(0, 12))

        # --- 皮肤 ---
        tk.Label(card, text="Theme", bg=self.c["card"], fg=self.c["fg"],
                 font=(F, 16, "bold")).pack(anchor="w", padx=24, pady=(22, 10))
        skin_row = tk.Frame(card, bg=self.c["card"])
        skin_row.pack(fill="x", padx=24)
        self.btn_light = self._theme_btn(skin_row, "☀ Light", LIGHT)
        self.btn_light.pack(side="left", ipadx=24, ipady=10)
        self.btn_dark = self._theme_btn(skin_row, "☾ Dark", DARK)
        self.btn_dark.pack(side="left", padx=16, ipadx=24, ipady=10)

        # --- 分隔 ---
        ttk.Separator(card, orient="horizontal").pack(fill="x", padx=24, pady=8)

        # --- 字体大小 ---
        tk.Label(card, text="Font Size", bg=self.c["card"], fg=self.c["fg"],
                 font=(F, 16, "bold")).pack(anchor="w", padx=24, pady=(16, 8))
        font_row = tk.Frame(card, bg=self.c["card"])
        font_row.pack(fill="x", padx=24)
        self.slider = ttk.Scale(font_row, from_=12, to=28, orient="horizontal",
                                command=self._on_slider, value=self.font_size)
        self.slider.pack(side="left", fill="x", expand=True)
        self.size_label = tk.Label(font_row, text="%d" % self.font_size,
                                   bg=self.c["card"], fg=self.c["accent"],
                                   font=(F, 18, "bold"), width=3)
        self.size_label.pack(side="left", padx=12)

        # --- 预览 ---
        tk.Label(card, text="Preview", bg=self.c["card"], fg=self.c["fg"],
                 font=(F, 16, "bold")).pack(anchor="w", padx=24, pady=(16, 8))
        self.preview = tk.Frame(card, bg=self.c["preview_bg"],
                                highlightbackground=self.c["border"],
                                highlightthickness=1)
        self.preview.pack(fill="both", expand=True, padx=24, pady=(0, 24))
        self.preview_text = tk.Label(self.preview, text="Hello 你好 1 2 3",
                                     bg=self.c["preview_bg"], fg=self.c["fg"],
                                     font=("Sans", self.font_size))
        self.preview_text.pack(expand=True)
        self._update_preview()

        # 底部提示
        tk.Label(body, text="Changes apply immediately", bg=self.c["bg"], fg=self.c["sub"],
                 font=(F, 12)).pack(anchor="w", padx=24, pady=(4, 12))

        self._refresh_buttons()

    def _theme_btn(self, parent, text, theme):
        btn = tk.Label(parent, text=text, cursor="hand2")
        btn._theme = theme
        btn.bind("<Button-1>", lambda e, t=theme: self._set_theme(t))
        return btn

    def _set_theme(self, theme):
        self.theme = theme
        self.dark = (theme == DARK)
        self._apply_theme(self.dark)
        # 重建所有部件（颜色变化）——简单起见重建 UI
        for w in self.winfo_children():
            w.destroy()
        self._build_ui()
        write_conf(self.font_size, self.theme)
        restart_fcitx()

    def _on_slider(self, val):
        self.font_size = int(float(val))
        self.size_label.config(text="%d" % self.font_size)
        self._update_preview()
        write_conf(self.font_size, self.theme)
        restart_fcitx()

    def _update_preview(self):
        self.preview_text.config(font=("Sans", self.font_size))

    def _refresh_buttons(self):
        for btn in (self.btn_light, self.btn_dark):
            active = (btn._theme == self.theme)
            btn.config(
                bg=self.c["accent"] if active else self.c["bg"],
                fg=self.c["accent_fg"] if active else self.c["fg"],
                font=("Sans", 16),
            )


if __name__ == "__main__":
    app = ImePanel()
    app.mainloop()
