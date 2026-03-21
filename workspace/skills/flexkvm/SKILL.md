---
name: flexkvm
description: Control remote computer through FlexKVM IP-KVM. Use when user needs mouse, keyboard, screenshots, scroll, or screen analysis. Can analyze screenshots using vision models. Triggers: move mouse, click, scroll, type, screenshot, capture screen, analyze image, control remote computer.
allowed-tools: Exec,ReadImage,SendFile,ReadFile,WriteFile,ListDir
---

# FlexKVM - Remote Computer Control Assistant

An intelligent assistant that can analyze screenshots and control remote computers through FlexKVM IP-KVM system.

## Configuration

| Item | Value |
|------|-------|
| CLI Path | `flexkvm_cli` |
| Screenshot Dir | `/tmp/` |
| Screenshot Path | `/tmp/screenshot.jpg` |

---

## Core Workflow: Screenshot Analysis

### Step 1: Take Screenshot

```bash
flexkvm_cli video --snapshot /tmp/screenshot.jpg
```

### Step 2: Analyze with Vision Model

Use `read_image` tool - this will send the image to vision model for analysis:

```
path: "/tmp/screenshot.jpg"
```

### Step 3: Vision Model Analysis Prompt

When you call read_image, the vision model will analyze and return:
1. **图片内容** - What's in the image (UI, text, objects)
2. **界面类型** - Interface type (login, desktop, app, error dialog, etc.)
3. **可交互元素** - Interactive elements and their **approximate positions**:
   - Buttons: 位置(左/中/右上/左下等), 颜色, 文字
   - Input fields: 位置, 大小
   - Menu items: 位置, 层级
   - Icons: 位置, 功能推测

### 重要: 分析截图时必须描述的元素

**必须包含以下信息：**

```
## 截图分析结果

### 1. 界面类型
- 这是什么界面？(桌面/浏览器/应用/登录/文件管理器等)
- 大致分辨率？

### 2. 鼠标信息
   - 是否存在鼠标指针？
   - 鼠标指针位置？

### 3. 主要元素位置 (坐标描述)
- 顶部栏: 窗口控制按钮(关闭/最小化/最大化)位置
- 任务栏: 开始菜单/托盘图标位置
- 主要内容区: 中心内容/主要按钮/输入框位置

### 4. 可点击元素
| 元素 | 位置 | 描述 |
|------|------|------|
| 按钮A | 右上角 | 颜色xx, 文字"确定" |
| 输入框 | 中心偏上 | 占位符"请输入..." |
| 链接 | 左侧 | 文字"了解更多" |

### 5. 下一步建议
- 需要点击哪个元素？
- 需要输入什么内容？
```

---

## Mouse Control

### Move Mouse

```bash
# Click at position (x,y) on 1920x1080 screen
flexkvm_cli mouse --abs 960,540 --res 1920x1080

# Left/Right click
flexkvm_cli mouse --click left
flexkvm_cli mouse --click right
flexkvm_cli mouse --click middle

# Relative movement (-127 to +127)
flexkvm_cli mouse --rel 50,0
```

### Mouse Drag

```bash
# Drag to absolute position (press, move, release)
flexkvm_cli mouse --drag-abs 800,600 --res 1920x1080

# Drag with relative movement
flexkvm_cli mouse --drag-rel 100,0
```

### Mouse Scroll Wheel

```bash
# Scroll up/down (positive=up, negative=down, range -127 to 127)
flexkvm_cli mouse --scroll 1
flexkvm_cli mouse --scroll -1
flexkvm_cli mouse --scroll -5

# Continuous scrolling
for i in {1..10}; do
    flexkvm_cli mouse --scroll -1
    sleep 0.1
done
```

### Mouse Mode

```bash
# Set absolute mode (default)
flexkvm_cli mouse --mode absolute

# Set relative mode
flexkvm_cli mouse --mode relative
```

### Mouse Jiggler (防屏保)

```bash
# Enable jiggler (keep mouse moving to prevent screensaver)
flexkvm_cli mouse --jiggler on

# Disable jiggler
flexkvm_cli mouse --jiggler off
```

### Check Mouse Status

```bash
flexkvm_cli mouse --info
# Output: {"connected": true, "enabled": true, "mode": "absolute", "jiggler": false}
```

---

## Keyboard Control

```bash
# Type text
flexkvm_cli keyboard --string "Hello World"

# Press key
flexkvm_cli keyboard --press enter

# Keyboard shortcuts
flexkvm_cli keyboard --press ctrl,c
flexkvm_cli keyboard --press ctrl,v
flexkvm_cli keyboard --press alt,f4
flexkvm_cli keyboard --press meta,r
```

---

## Complete Workflow Examples

### Example 1: Analyze Screen and Click Button

User: "点击确定按钮"

1. Take screenshot
2. Use read_image tool to analyze
3. Vision model returns button location
4. Click at that position:

```bash
flexkvm_cli mouse --abs 960,540 --res 1920x1080
flexkvm_cli mouse --click left
```

### Example 2: Scroll and Find Element

User: "向下滚动，找到设置按钮"

1. Scroll down: `flexkvm_cli mouse --scroll -3`
2. Take new screenshot
3. Analyze with read_image
4. Find settings button location
5. Click it

### Example 3: Type in Input Field

User: "在搜索框输入 hello"

1. Analyze screenshot to find input field position
2. Click in the input field
3. Type: `flexkvm_cli keyboard --string "hello"`
4. Press Enter: `flexkvm_cli keyboard --press enter`

---

## Video Control

```bash
# Get video info
flexkvm_cli video --info

# Set video quality (low/medium/high/ultra)
flexkvm_cli video --mode high
```

1. **Always analyze screenshot first** - Use read_image tool to understand what's on screen

2. **Vision analysis must include positions** - Always describe approximate coordinates/regions:
   - "右上角的关闭按钮"
   - "左侧边栏第二个图标"
   - "底部任务栏中央的开始按钮"

3. **Screen resolution**: Default is 1920x1080

4. **Delays**: Add `sleep 0.3` between actions

---

## Quick Reference

| Task | Command |
|------|---------|
| Screenshot | `flexkvm_cli video --snapshot /tmp/screenshot.jpg` |
| Analyze | Use `read_image` tool |
| Move mouse | `flexkvm_cli mouse --abs X,Y --res WxH` |
| Left/Right/Middle click | `flexkvm_cli mouse --click left/right/middle` |
| Drag | `flexkvm_cli mouse --drag-abs X,Y --res WxH` |
| Scroll | `flexkvm_cli mouse --scroll ±N` |
| Jiggler on/off | `flexkvm_cli mouse --jiggler on/off` |
| Type text | `flexkvm_cli keyboard --string "text"` |
| Press key | `flexkvm_cli keyboard --press key` |
| Keyboard shortcut | `flexkvm_cli keyboard --press ctrl,c` |
| Send file | Use `send_file` tool |
| Video quality | `flexkvm_cli video --mode high` |

---

## Version

- v1.2 - Vision model integration with detailed position analysis
