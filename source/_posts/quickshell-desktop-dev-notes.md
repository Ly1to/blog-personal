---
title: Quickshell 桌面开发实录：环境、样式体系与隔离策略
date: 2026-11-11 23:45:00
tags:
  - Quickshell
  - niri
  - Wayland
  - QML
  - Linux 桌面
categories:
  - 折腾记录
---

> 在 Arch + niri 上从零写一个 Quickshell 桌面外壳：基本路径怎么走、组件样式分几层设计、以及怎样避免和系统里已有的 shell（Clavis）打架。
>
> 环境：Arch Linux / niri 26.04 / Wayland / Quickshell 0.3.2（Qt 6.12），单屏 DP-3。

---

## 0. 本机现状

| 项 | 值 |
| --- | --- |
| 系统 / 会话 | Arch Linux，Wayland，niri 26.04 |
| Quickshell | 0.3.2（`/usr/bin/qs`） |
| 已有依赖 | qt6-declarative/wayland/svg/5compat、pipewire、wireplumber、upower、networkmanager |
| 字体 | LXGW WenKai Screen、JetBrainsMono Nerd Font Mono、Material Symbols Rounded |
| 现成参考 | `clavis-shell` 包：`/etc/xdg/quickshell/clavis`（427 个 QML），由 `clavis-shell.service` 常驻 |
| 其他工具 | matugen（动态取色）、awww（壁纸）、key-cli（Clavis 的附属 CLI） |

关键一点：**系统里已经有一个完整 shell 在运行**（`qs -c clavis -n`），既是绝佳参考，也是开发时的主要“冲突源”。

---

## 1. 基本路径

### 1.1 运行形态

Quickshell 按 `xdg/quickshell/<name>/shell.qml` 识别命名配置，也支持直接给路径：

```bash
cd ~/Projects/quickshell/archdesktop
qs -p .                 # 目录开发，保存即热重载（已验证）
qs -p . -v              # INFO 内部日志
qs -p . -vv             # DEBUG
qs ipc list             # 列出运行中的实例
qs ipc -p . call archdesktop state
```

稳定后再挂到 XDG 配置目录，用 `qs -c archdesktop`；开机自启写 niri：

```kdl
spawn-at-startup "qs" "-c" "archdesktop" "-n"
```

或者仿照 `clavis-shell.service` 写一个 `PartOf=niri.service` 的 systemd user unit。

### 1.2 最小骨架

```
archdesktop/
├── shell.qml                 # ShellRoot + 每个屏幕一个 Bar + IpcHandler
├── Common/
│   ├── qmldir                # singleton Theme
│   └── Theme.qml             # 颜色 / 字体 / 尺寸令牌
├── Services/
│   ├── qmldir                # singleton Niri
│   └── Niri.qml              # niri msg --json 快照 + event-stream
└── Modules/Bar/
    ├── Bar.qml               # PanelWindow(layer-shell)
    ├── Workspaces.qml        # 工作区指示 + 点击切换
    └── Clock.qml             # SystemClock
```

```qml
// shell.qml
import QtQuick
import Quickshell

import "Modules/Bar"

ShellRoot {
    // 每个显示器一个 Bar，热插拔自动增删
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {
                required property ShellScreen modelData
                screen: modelData
            }
        }
    }
}
```

### 1.3 niri 集成

niri 不像 Hyprland 有 Quickshell 原生模块，走 IPC 即可：

- 查询：`niri msg --json workspaces|outputs|windows|focused-output`
- 推送：`niri msg --json event-stream`（常驻进程 + `SplitParser`）
- 动作：`niri msg action focus-workspace <idx>`、`spawn`、`close-window` 等
- 快捷键：niri `spawn "qs" "-c" ... "ipc" "call" ...`，参考 `~/.config/niri/clavis/binds.kdl`

工作区状态的简单可靠写法：`WorkspacesChanged` 直接整体替换，其余事件 40ms 防抖后重新查询（比逐字段推导事件更不容易漏）。

### 1.4 落地顺序

1. Bar 骨架：工作区 + 时钟 + 主题，跑通热重载与 niri IPC
2. 系统状态：音量（Pipewire）、电池（UPower）、网络（nmcli）、蓝牙、托盘
3. 弹窗面板：PopupWindow + PopupAnchor，音量滑块 / Wi-Fi 列表 / 电源菜单
4. 通知 + OSD：NotificationServer 接管；音量/亮度提示
5. 启动器 / Spotlight：DesktopEntries 搜索 + 常用命令，IPC 唤起
6. 锁屏 / 空闲：WlSessionLock + IdleNotify
7. 截图/录屏、剪贴板、overview、多屏、性能

---

## 2. 组件样式是怎么设计的

Quickshell 没有 CSS，“样式”不是样式表，而是 **QML 组件 + 设计令牌单例**：颜色、字体、间距、圆角、动效都是属性，靠分层 + 可复用组件 + `Behavior` + 合成器规则组合起来。

`clavis-shell` 的分层可以直接当范本：

```
L0 原始色板    Common/Appearance.qml:96-143   m3colors（M3 全套）
L1 语义色角色  Common/Appearance.qml:145-250  colLayer0..4 / colOn* / *Hover / *Active
L2 字体        Common/Typography.qml          display/headline/title/body/label 12 级
L3 尺寸        Common/Metrics.qml, Sizes.qml  spacing/icon/controlHeight/corner/barHeight
L4 动效        Common/Animations.qml          M3 bezier 曲线 + durations
L5 交互        Widgets/common/StateLayer.qml  hover/focus/pressed 状态层
L6 组件        Widgets/common/*               RippleButton, BarCircularButton, MaterialCard…
L7 模块        Modules/Bar/QuickSettings/*    只绑状态，不画样式（SettingsButton 仅 31 行）
L8 表面        Modules/Bar/HorizontalBarWindow  PanelWindow + 阴影/模糊/输入区域
```

### 2.1 令牌层：原始色 → 语义色 → 状态色

```qml
// L0: matugen 生成的 colors.json 被 FileView 监听，换壁纸即热更新
FileView { id: colorFile; path: root.colorsPath; watchChanges: true
    onLoaded: root.applyGeneratedColors(colorFile.text()) }

// L1: 组件只认语义名
colors: QtObject {
    property color colLayer1Base: root.m3colors.m3surfaceContainerLow
    property color colLayer1:     root.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - contentTransparency)
    property color colOnLayer1:   root.m3colors.m3onSurfaceVariant
    property color colLayer1Hover: root.transparentize(root.mix(colLayer1, colOnLayer1, 0.92), contentTransparency)
    property color colPrimary: root.m3colors.m3primary
    property color colPrimaryHover: root.mix(colPrimary, colLayer1Hover, 0.87)
}
```

关键设计：**玻璃/半透明效果不能用 `opacity`**（会连带子元素一起透明），而是用 rgba 颜色 + `solveOverlayColor(base, target, opacity)` 反解覆盖色。这样透明主题下 hover 叠色的观感仍然正确。

同理：`Typography` 的每一级都绑定 `Fonts.ui`，换字体全局生效；`Metrics` 用语义名（`iconM`、`controlHeightM`、`cornerXL`）而不是裸数字。

### 2.2 组件层：参数化 + 令牌默认值 + 状态层 + Behavior

```qml
// A. 颜色属性 = 令牌默认值，调用方只覆盖语义
BarCircularButton {
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color iconColor:      Appearance.colors.colOnPrimaryContainer
    property real  baseSize:       Sizes.barControlCircleSize   // 28
    property real  hoverSize:      34
    implicitWidth: baseSize; implicitHeight: baseSize
}

// B. 状态层只动画 opacity
StateLayer {
    hovered: ...; pressed: ...
    hoverOpacity:   Appearance.interaction.hoverStateLayerOpacity    // 0.08
    pressedOpacity: Appearance.interaction.pressedStateLayerOpacity  // 0.12
    Behavior on opacity { NumberAnimation {
        duration: Appearance.interaction.stateLayerTransitionDuration  // 150ms
        easing.type: Appearance.animation.expressiveFastEffects.type
        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
    }}
}

// C. 尺寸变化用 Behavior，不要动 font.pixelSize
Behavior on width { NumberAnimation { duration: ... } }
```

图标也是样式的一部分，用可变字体轴：

```qml
// Components/MaterialSymbol.qml
font {
    family: Fonts.materialSymbolsRounded
    pixelSize: renderedIconSize                 // 必须取整
    variableAxes: { "FILL": fill, "opsz": opticalSize }
}
renderType: Text.NativeRendering
```

`pixelSize` 必须 `Math.round`：每出现一个新的 pixelSize，Qt 就建一个新的可变字体 face，动画中的小数尺寸会耗尽内存——这是实打实的坑。

### 2.3 表面层：窗口怎么“长”成顶栏

`PanelWindow` 默认是透明表面，外观自己画，再交给 niri 的 layer-rule：

```qml
PanelWindow {
    implicitHeight: outerEdgeMargin + visualThickness + shadowBuffer  // 给阴影留像素
    color: "transparent"
    exclusiveZone: outerEdgeMargin + visualThickness   // 只有实体部分占桌面空间
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "archdesktop-bar"

    Item { id: visualBand; y: outerEdgeMargin; height: visualThickness }
    CompositorBlurRegion { targetWindow: root; backgroundItem: ...; radius: 18 }
    mask: Region { ... }        // 精确控制可点击区域
}
```

合成器侧（niri ≥ 26.4）：

```kdl
layer-rule {
    match namespace="^archdesktop-bar$";
    background-effect { blur true; xray false; }
    opacity 0.92;
    geometry-corner-radius 18;
}
```

`niri msg layers` 可以直接检查每个 namespace 的层级与键盘交互状态。

### 2.4 样式坑清单

- `opacity` 会把子元素一起透明 → 用 rgba / `solveOverlayColor`
- 动画 `font.pixelSize` / 可变字体轴会不断创建字体 face → 只动画容器几何，图标尺寸取整
- 颜色过渡要用 `ColorAnimation`，`NumberAnimation` 对 color 无效
- 阴影/圆角超出表面会被裁 → `implicitHeight` 预留 `shadowBuffer`（Clavis 用 36px）
- `exclusiveZone` 与 niri `struts` 别双重占位
- 大量 `Behavior` + `ShaderEffect` 会拖 GPU；模糊交给合成器，别用全窗口 `ShaderEffectSource`

---

## 3. 和现有 shell 的冲突与隔离

### 3.1 不会冲突的部分

| 项 | 原因 |
| --- | --- |
| QML / 字体 / 语法 | `-p` 或独立 config 名，与 `-c clavis` 完全隔离 |
| Quickshell 实例 / IPC | 每个 config 独立 `by-id` 运行时目录与 IPC socket（已实测并存） |
| 缓存 / 日志 | 按实例 hash 分开存放 |
| niri 快捷键 | 各 `binds` 并存，只有同键重复绑定才冲突 |

### 3.2 会冲突的部分（本机实测）

| 冲突面 | 证据 / 说明 |
| --- | --- |
| layer 表面 + 占用区 | 两条顶栏同时存在，`exclusiveZone` 叠加，窗口被顶两次 |
| DBus 单例 | `qs` pid 908 持有 `org.freedesktop.Notifications`、`org.kde.StatusNotifierWatcher`、`StatusNotifierHost` |
| 锁屏 / 空闲 | `WlSessionLock` 同时只能一个；Clavis 的 IdleService 也在跑 |
| 壁纸 | `awww-daemon --namespace clavis-desktop` 是 Clavis 的管线 |
| 剪贴板 | `clavis-clipboard.service` 单独跑 `key clipboard watch` |
| niri 配置托管 | `~/.config/niri/clavis/*.kdl` 由 Clavis 写入；`niri_config.py` 还会往 `config.kdl` 追加 include |
| portal / app id | 空配置启动也会看到 `Could not register app ID ... already associated` 警告 |
| 资源 | Clavis 实测 RSS 717 MB、CPU 10% |

结论：**写 QML、调布局、做动效，本机并行没问题；涉及通知/托盘/锁屏/壁纸时就必须二选一**。

### 3.3 隔离方案（按侵入程度递增）

#### 档位 1：本机并行

```bash
qs -p ~/Projects/quickshell/archdesktop
```

开发期把 bar 改成不占位、浮在最上层：

```qml
exclusiveZone: 0
WlrLayershell.layer: WlrLayer.Overlay
```

namespace 用 `archdesktop-` 前缀，避免撞 Clavis 的 `clavis-shell-bar-*` 规则。

#### 档位 2：互斥切换

```bash
systemctl --user stop clavis-shell clavis-clipboard   # 让出通知/托盘/锁屏/壁纸
qs -p ~/Projects/quickshell/archdesktop
systemctl --user start clavis-shell clavis-clipboard  # 恢复
```

`clavis-shell.service` 是 `PartOf=niri.service` 的普通用户服务，随时可停可起，应用和窗口不受影响。

#### 档位 3：嵌套 niri（推荐替代 VM）

niri 自带 winit 后端，可在当前会话里开一个独立合成器窗口：自己的 Wayland socket、IPC socket、输出和 layer 规则。

```bash
mkdir -p ~/dev/niri-dev
cat > ~/dev/niri-dev/config.kdl <<'EOF'
input { }
layout { gaps 8 }
spawn-at-startup "qs" "-p" "/home/LycOor/Projects/quickshell/archdesktop"
binds { Mod+Return { spawn "kitty"; } }
EOF

niri validate -c ~/dev/niri-dev/config.kdl
niri -c ~/dev/niri-dev/config.kdl
```

本机实测：

```
$ niri msg layers        # 通过嵌套实例 socket 查询
Output "winit":
  Top layer:
    Surface:
      Namespace: "archdesktop-bar"
```

从宿主机操作嵌套实例：

```bash
SOCK=$(ls -t /run/user/1000/niri.wayland-2.*.sock | head -1)
NIRI_SOCKET=$SOCK niri msg layers
NIRI_SOCKET=$SOCK niri msg action focus-workspace 2
```

优点：零成本、全速 GPU、真实 niri 版本，可随便改 layer-rule / 模糊 / 圆角，也能把 Clavis 塞进去对比。
缺点：共享同一个 DBus session（通知/托盘仍会撞名字）；输入要先点进嵌套窗口。

需要隔离 DBus 时：

```bash
# A. 私有 session bus（最干净，但 PipeWire/UPower 不可用）
dbus-run-session -- niri -c ~/dev/niri-dev/config.kdl
# B. 只停 Clavis（保留音频/电源服务，推荐）
systemctl --user stop clavis-shell && niri -c ~/dev/niri-dev/config.kdl
```

#### 档位 4：独立 TTY / 独立用户

niri 支持“非主实例”（不要加 `--session`）：

```bash
# Ctrl+Alt+F3
niri -c ~/dev/niri-dev/config.kdl
```

完全独立的 DBus、systemd 目标、XDG 配置，真实 GPU；代价是切 VT。

#### VM 呢？

不建议作为日常开发环境：这套东西的价值全在 layer-shell + niri 版本行为 + 真实 GPU（模糊、帧同步、多显示器、缩放），virtio-gpu 下会失真，且调试链路变长。VM 只适合验证不同版本或干净安装的打包行为。

### 3.4 三条硬性规矩

- 不改 `/etc/xdg/quickshell/clavis`（包管理文件，升级即覆盖）
- 不改 `~/.config/niri/clavis/*.kdl`，自己的规则放独立 include
- 并行时不要启用 `NotificationServer`、`SystemTray`、`WlSessionLock` 这类注册全局名字的服务

---

## 4. 速查

| 操作 | 命令 |
| --- | --- |
| 开发运行 | `qs -p ~/Projects/quickshell/archdesktop` |
| 详细日志 | `qs -p . -v` / `-vv` |
| 实例列表 | `qs ipc list` |
| 调试接口 | `qs ipc -p . call archdesktop state` |
| 实例日志 | `tail -f /run/user/1000/quickshell/by-id/*/log.qslog` |
| 检查 layer 表面 | `niri msg layers` |
| 校验 niri 配置 | `niri validate -c config.kdl` |
| 停/起 Clavis | `systemctl --user stop/start clavis-shell clavis-clipboard` |
| 嵌套 niri | `niri -c ~/dev/niri-dev/config.kdl` |

---

## 参考

- Quickshell：<https://quickshell.org>
- niri：<https://github.com/YaLTeR/niri>
- 本机参考实现：`/etc/xdg/quickshell/clavis`（`Common/Appearance.qml`、`Common/Typography.qml`、`Widgets/common/StateLayer.qml`、`Modules/Bar/HorizontalBarWindow.qml`）
- 脚手架：`~/Projects/quickshell/archdesktop`
