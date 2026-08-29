# Tate_ASQ

**Tate's AutoSpellQueue** — 魔兽世界正式服（12.x）插件。

**By Tate Chen**

自动根据职业/专精、网络延迟与当前场景，调整 `SpellQueueWindow`（施法队列窗口 / 施法容错）。

---

## 这是什么？为什么有用？

魔兽的「施法队列窗口」决定：**你可以在当前技能/GCD 结束前多少毫秒预输入下一个技能**。

- 值太小：网络稍有延迟，技能之间容易断档，损失输出。
- 值太大：技能会「太黏」，容易把不该排的技能排进去，近战尤其明显。

暴雪默认值是 400ms，对多数人偏高。Tate_ASQ 会根据职业/专精和当前网络，帮你自动设到更合适的值。

---

## 工作原理

### 1. 职业/专精基础值

插件内置一张草表（`Tate_ASQ_Formula.lua`），按职业/专精给基础值。原则：

- 高 APM 近战 / 连击点职业（盗贼、踏风）：140ms 左右，保持反应速度。
- 标准近战（战士、惩戒等）：150ms。
- 坦克（防战、血 DK 等）：160ms，稍微方便排减伤。
- 远程瞬发（兽王猎）：190ms。
- 读条法系（火法、毁灭术等）：240ms 左右，保证读条衔接。
- 其他远程/治疗：介于中间。

### 2. 网络延迟自适应

插件读取 `GetNetStats()` 的 **World（世界/战斗服务器）延迟**：

```
延迟需求 = World延迟 + 50ms 余量
最终值   = clamp( max(职业基础值, 延迟需求), 50, 400 )
```

- 网络好：延迟需求低于基础值 → 用基础值。
- 网络差：延迟需求超过基础值 → 用延迟算出的更高值。
- World 延迟不可用时，回退使用 Home 延迟。

### 3. 城市 / 副本不同算法

| 场景 | 计算方式 | 原因 |
|---|---|---|
| 城市（安全区） | 直接用职业基础值 | 城市里没有战斗，不需要追延迟 |
| 副本 / 团本 | 基础值 + 延迟自适应 | 战斗强度最高，保证技能不断档 |
| 野外 | 基础值 + 延迟自适应 | 可能发生战斗/PvP |

判断方式：

- 副本/团本：`IsInInstance()`
- 城市：`C_Map.GetMapInfo` 的 `IsCityMap` 标记
- 其余视为野外

### 4. 什么时候会重新计算并写入

- 进入游戏（`PLAYER_ENTERING_WORLD`）
- 切换专精/天赋（`PLAYER_SPECIALIZATION_CHANGED`）
- 场景变化，例如进出副本、进出城市（`ZONE_CHANGED_NEW_AREA`）
- 在设置页手动修改配置

没有定时器，不做周期性覆盖。战斗中触发的写入会推迟到脱战。

---

## 主要功能

- 默认启用。
- 基础值模式：
  - **自动**：按职业/专精表。
  - **手动**：使用你指定的固定基础值。
- 延迟自适应可开关。
- 悬浮状态条只显示当前 `SpellQueueWindow` 值，可拖动，左键点击打开设置。
- 状态条字体可选（WoW 内置 / LibSharedMedia，若存在），字号可调，状态条随字号自动缩放。
- 设置页顶部显示**计算式**，让你知道当前值是怎么来的。
- 中英文自动切换（zhCN / zhTW / 英文兜底）。
- 关闭插件时，若当前值仍是本插件最后写入的值，会恢复启用前的旧值。

---

## 设置入口

- 游戏菜单 → 选项 → 插件 → 施法容错。
- 悬浮状态条左键点击。

---

## 安装

1. 下载最新版：[Tate_ASQ-v1.0.0.zip](https://github.com/tatechen88/Tate_ASQ/releases/download/v1.0.2/Tate_ASQ-v1.0.2.zip)
2. 解压后把 `Tate_ASQ` 文件夹放到 `World of Warcraft\_retail_\Interface\AddOns\`。
3. 进入游戏，插件会自动启用。

---

## 默认参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| enabled | true | 总开关 |
| baseMode | auto | auto = 职业/专精表；manual = 手动 |
| manualBase | 200 | 手动模式基础值 |
| adaptive | true | 是否叠加延迟自适应 |
| latencySource | world | 固定世界延迟，World 不可用时回退 Home |
| margin | 50 | 延迟余量 |
| minWindow | 50 | 最终值下限 |
| maxWindow | 400 | 最终值上限 |
| hysteresis | 10 | 写入迟滞 |
| showStatus | true | 显示悬浮状态条 |
| statusFont | Fonts\FRIZQT__.TTF | 状态条字体 |
| statusFontSize | 12 | 状态条字号 |

---

## 文件结构

```
Tate_ASQ.toc
Tate_ASQ_Formula.lua    -- 纯计算：职业/专精基础值 + 延迟 + 场景
Tate_ASQ.lua            -- 运行时：事件、CVar 读写、恢复逻辑
Tate_ASQ_Options.lua    -- 设置窗口、状态条、标准选项页
```

---

## 注意

- `GetNetStats()` 约 30 秒才更新一次；延迟变化后，最长约 30 秒才能在下一次重算时体现。
- 职业/专精基础值草表可在 `Tate_ASQ_Formula.lua` 顶部调整。

---

## 繁體中文說明

**Tate_ASQ** 是《魔獸世界》正式服（12.x）插件，會依職業/專精、網路延遲與目前場景，自動調整 `SpellQueueWindow`（施法佇列視窗 / 施法容錯）。

- 預設啟用。
- 城市：直接使用職業/專精基礎值。
- 副本 / 野外：基礎值 + 世界延遲自適應（World 優先，Home 回退）。
- 進入遊戲、切換專精、進出副本/城市時自動重新計算。
- 懸浮狀態條顯示目前值，可拖曳、可記憶位置、可調整字體與字號。
- 設定入口：選項 → 插件 → 施法容錯；或左鍵點擊狀態條。
- 支援繁體中文（zhTW）、簡體中文（zhCN）與英文。

下載：https://github.com/tatechen88/Tate_ASQ/releases/download/v1.0.2/Tate_ASQ-v1.0.2.zip

---

## English

**Tate_ASQ** is a World of Warcraft retail (12.x) addon that automatically adjusts `SpellQueueWindow` based on your class/spec, current latency, and location.

- Enabled by default.
- City: uses the class/spec base value directly.
- Instance / open world: base value + world latency adaptation (World first, Home fallback).
- Recalculates on entering game, changing spec, or changing zone (city / instance / open world).
- Floating status bar shows the current value; draggable, remembers position, font and size adjustable.
- Settings: Options → AddOns → 施法容错, or left-click the status bar.
- Supports English, Simplified Chinese (zhCN), and Traditional Chinese (zhTW).

Download: https://github.com/tatechen88/Tate_ASQ/releases/download/v1.0.2/Tate_ASQ-v1.0.2.zip

