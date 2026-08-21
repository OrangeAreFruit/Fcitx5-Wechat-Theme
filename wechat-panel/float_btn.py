#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fcitx5 轻量浮动按钮 —— 极轻量(Tkinter, 系统内置, ~5MB, 无Web引擎)
功能:
  - 屏幕边缘一个圆形小按钮, 图标随主题显示 ☀ 或 ☾
  - 点击展开一行: [☀/☾ 切换] [− 字号] [＋ 字号]
  - 可拖动, 置顶, 无边框无大矩形背景
用法:  /usr/bin/python3 float_btn.py
"""
import os
import re
import subprocess
import tkinter as tk
from tkinter import simpledialog

CFG = os.path.expanduser("~/.config/fcitx5/conf/classicui.conf")
THEMES = ("wechat-dark", "wechat-light")
POST = os.path.expanduser("~/.local/share/applications/ime-panel.desktop")


def read_conf():
    size, theme = 14, "dark"
    if os.path.exists(CFG):
        try:
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
        except OSError:
            pass
    return size, theme


def write_conf(size, theme):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    c = ""
    if os.path.exists(CFG):
        try:
            with open(CFG, "r", encoding="utf-8") as f:
                c = f.read()
        except OSError:
            c = ""
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


def restart_fcitx():
    try:
        subprocess.run(["fcitx5-remote", "-r"], check=False, timeout=5)
        return
    except FileNotFoundError:
        pass
    subprocess.run(["pkill", "-x", "fcitx5"], check=False)
    subprocess.Popen(["fcitx5", "-d"], start_new_session=True)


BTN = 40            # 主按钮直径
BALL_CLR = "#07C160"  # 微信绿
BAR_CLR = "#ffffff"


class FloatBtn:
    def __init__(self):
        self.root = tk.Tk()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.bg = "#000000"
        self.root.config(bg=self.bg)
        self.fsize, self.theme = read_conf()
        self.expanded = False
        self.widgets = []

        # 放置: 屏幕右侧中部
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        self.x, self.y = sw - BTN - 24, sh // 2
        self.root.geometry("%dx%d+%d+%d" % (1, 1, self.x, self.y))

        self.main_btn = None
        self._build_main()
        self._place(self.x, self.y)
        self._drag_init()

    # ---------- 布局 ----------
    def _placement(self):
        return self.x, self.y

    def _place(self, x, y):
        self.x, self.y = x, y
        self.root.geometry("+%d+%d" % (x, y))

    def _icon(self):
        return "☾" if self.theme == "dark" else "☀"

    def _build_main(self):
        self.main_btn = tk.Label(
            self.root, text=self._icon(), bg=BALL_CLR, fg="white",
            font=("Sans", 18), cursor="hand2", width=2, height=1)
        self.main_btn.place(x=0, y=0, width=BTN, height=BTN)
        self.main_btn.bind("<Button-1>", self._toggle_bar)

    # 展开的一行按钮
    def _build_bar(self):
        self.bar = tk.Frame(self.root, bg=BAR_CLR, bd=0,
                            highlightthickness=1, highlightbackground="#e0e0e0")
        # 主题切换按钮
        self.skin_btn = tk.Label(self.bar, text=self._icon(),
                                 bg=BAR_CLR, fg="#333", font=("Sans", 14),
                                 cursor="hand2", relief="flat", bd=0)
        self.skin_btn.pack(side="left", padx=6, pady=3)
        self.skin_btn.bind("<Button-1>", lambda e: self._toggle_theme())
        # 字号 减/加
        self.minus = tk.Label(self.bar, text="−", bg=BAR_CLR, fg="#333",
                              font=("Sans", 16), cursor="hand2", relief="flat", bd=0)
        self.minus.pack(side="left", padx=(2, 8), pady=3)
        self.minus.bind("<Button-1>", lambda e: self._step_font(-1))
        self.fsize_lb = tk.Label(self.bar, text=str(self.fsize), bg=BAR_CLR,
                                 fg="#333", font=("Sans", 11, "bold"), width=2)
        self.fsize_lb.pack(side="left", pady=3)
        self.plus = tk.Label(self.bar, text="＋", bg=BAR_CLR, fg="#333",
                             font=("Sans", 16), cursor="hand2", relief="flat", bd=0)
        self.plus.pack(side="left", padx=(8, 6), pady=3)
        self.plus.bind("<Button-1>", lambda e: self._step_font(1))
        self.bar.update_idletasks()
        bw = self.bar.winfo_reqwidth()
        bh = self.bar.winfo_reqheight()
        # 整窗尺寸调整后重新定位, 按钮在左侧, 展开条向右
        self.root.geometry("%dx%d+%d+%d" % (BTN + bw, BTN, self.x, self.y))
        self.bar.place(x=BTN, y=0, height=BTN)

    def _toggle_bar(self, _evt=None):
        if self.expanded:
            self._collapse()
        else:
            self._expand()

    def _expand(self):
        self._build_bar()
        self.expanded = True

    def _collapse(self):
        for w in getattr(self, "widgets", []):
            try:
                w.destroy()
            except Exception:
                pass
        if hasattr(self, "bar"):
            try:
                self.bar.destroy()
            except Exception:
                pass
        self.root.geometry("%dx%d+%d+%d" % (BTN, BTN, self.x, self.y))
        # 重新放置主按钮
        self.main_btn.place(x=0, y=0, width=BTN, height=BTN)
        self.expanded = False

    # ---------- 动作 ----------
    def _apply(self):
        write_conf(self.fsize, self.theme)
        self.main_btn.config(text=self._icon())
        try:
            self.skin_btn.config(text=self._icon())
        except Exception:
            pass
        try:
            self.fsize_lb.config(text=str(self.fsize))
        except Exception:
            pass
        restart_fcitx()

    def _toggle_theme(self):
        self.theme = "light" if self.theme == "dark" else "dark"
        self._apply()

    def _step_font(self, d):
        self.fsize = max(12, min(28, self.fsize + d))
        self._apply()

    # ---------- 拖动 ----------
    def _drag_init(self):
        self._sx = self._sy = 0
        self.main_btn.bind("<ButtonPress-1>", self._p1, add="+")
        self.main_btn.bind("<B1-Motion>", self._m1, add="+")

    def _p1(self, e):
        self._sx, self._sy = e.x_root, e.y_root

    def _m1(self, e):
        nx = self.x + (e.x_root - self._sx)
        ny = self.y + (e.y_root - self._sy)
        self.x, self.y = nx, ny
        self.root.geometry("+%d+%d" % (nx, ny))


if __name__ == "__main__":
    app = FloatBtn()
    app.root.mainloop()
