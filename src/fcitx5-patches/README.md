# fcitx5 核心改动补丁（基于 5.1.22 源码）

这套文件让自编译的 fcitx5 候选框具备「微信输入法式」体验。
文件为**直接可覆盖的源码版本**（保留相对路径），使用时复制到 fcitx5 源码对应位置，重新编译对应模块即可。

## 文件清单

| 本目录路径 | 复制到 fcitx5 源码 | 模块 |
|---|---|---|
| `ui/classic/inputwindow.h` / `.cpp` | `src/ui/classic/` | classicui（候选框） |
| `ui/classic/classicui.cpp` | `src/ui/classic/` | classicui（配置监听/重绘） |
| `modules/notificationitem/notificationitem.cpp` | `src/modules/notificationitem/` | notificationitem（托盘） |

## 功能说明

### classicui（候选框）
- **右下角绿色圆环设置按钮**：位于最后一个候选右侧，点击唤起外部设置面板（`fcitx5-wechat-panel` 的 `run-panel.sh`）；鼠标悬停浮现浅蓝圆角背景。
- **右键菜单**：候选框右键弹出「设置/主题/重启输入法」菜单。
- **主题/字号即时生效**：监听 `~/.config/fcitx5/conf/classicui.conf` 变化自动重载并重绘，无需重启 fcitx5。
- **布局预留**：右侧为设置按钮预留 space，避免被窗口边缘裁切。

### notificationitem（托盘图标 + 菜单）
- 托盘图标固定为自定义图标名 `fcitx-wusong`（绿色圆角方块 + 双弯叶），位图直传 `IconPixmap`（从 `/usr/share/icons/hicolor/{16,22,32,48,64}x*/apps/fcitx-wusong.png` 读取），并设置 `IconThemePath=/usr/share/icons/hicolor/`。
- 菜单精简为两项：**Preference**（点击启动设置面板，带绿色圆环图标）与 **Restart**（重启 fcitx5）。

### 依赖图标
- `/usr/share/icons/hicolor/scalable/apps/fcitx-wusong.svg`：源图（可自行替换定制）
- 各尺寸 PNG：由 `rsvg-convert` 生成（注意：**不要用 ImageMagick `convert` 渲染 SVG**，它会丢失白色描边）

## 编译
```bash
cmake -S <fcitx5-src> -B build -DENABLE_TEST=OFF
cmake --build build --target classicui notificationitem -j$(nproc)
# 产物替换 /usr/lib/x86_64-linux-gnu/fcitx5/libclassicui.so 与 libnotificationitem.so
```

## 配套设置面板
见仓库根目录 `wechat-panel/`（pywebview + QtWebEngine 透明圆角面板，支持主题/字号实时调节、置顶、拖动）。