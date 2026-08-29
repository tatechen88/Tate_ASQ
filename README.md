# EllesmereUI_AutoSpellQueue

魔兽世界正式服（12.x）插件：根据当前职业/专精与网络延迟，自动调整 `SpellQueueWindow`（施法队列窗口 / 施法容错）。

依赖 [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI)。本插件**不修改 EllesmereUI 本体**，独立安装在其旁边的 `Interface\AddOns\EllesmereUI_AutoSpellQueue` 文件夹中。

## 特性

- 默认启用。
- 仅在**进入游戏**与**切换专精（天赋）**时自动判定并写入；无定时器，不周期覆盖。
- 基础值按职业/专精差异化（例如盗贼 140ms、战士 150ms、兽王猎 190ms、火法 245ms 等），而非单一近战/远程数值。
- 延迟自适应：`最终值 = clamp(max(职业基础值, 当前延迟 + 余量), 下限, 上限)`。
- 设置项变更立即生效（用户操作触发）。
- 设置窗口 + 可拖动状态条，显示当前本地/世界延迟与当前 `SpellQueueWindow`。
- 中英文自动切换（zhCN / zhTW / enUS，英文为默认兜底）。
- 没有 slash 命令；通过**插件收纳盒按钮**（小地图旁）或状态条左键点击打开设置。

## 安装

1. 下载并解压到 `World of Warcraft\_retail_\Interface\AddOns\`，确保文件夹名为 `EllesmereUI_AutoSpellQueue`。
2. 确保已安装 `EllesmereUI`。
3. 进入游戏，插件会自动启用并应用第一次计算。

## 设置

- 点击小地图旁的插件收纳盒（Addon Compartment）中的按钮，或左键点击状态条，打开设置窗口。
- 设置窗口内可调整：
  - 启用 / 关闭
  - 基础值模式：自动（按职业/专精表）或手动
  - 手动基础值
  - 延迟自适应开关
  - 延迟来源（World / Home / Average / Max）
  - 延迟余量、下限、上限、写入迟滞
  - 状态条显示开关
- 状态条可拖动；左键点击打开设置。

## 默认参数

| 参数 | 默认值 |
|---|---|
| enabled | true |
| baseMode | auto |
| manualBase | 200 |
| adaptive | true |
| latencySource | max |
| margin | 50 |
| minWindow | 50 |
| maxWindow | 400 |
| hysteresis | 10 |
| showStatus | true |

## 计算逻辑

计算逻辑独立在 `EllesmereUI_AutoSpellQueue_Formula.lua`，不碰 CVar、事件与 UI：

- `Classify(specID, classFile)` → 近战 / 远程
- `GetBase(cfg, specID, classFile)` → 职业/专精基础值
- `PickLatency(source, home, world)` → 选择延迟
- `ComputeTarget(cfg, specID, classFile, home, world)` → 最终目标值

职业/专精基础值草表可在该文件顶部调整。

## 注意

- `GetNetStats()` 的延迟值约 30 秒才刷新一次；因此延迟变化后，最长约 30 秒才能在下一次进入游戏/切专精时体现到计算中。
- 战斗中触发的写入会推迟到脱战。
- 关闭插件时，若当前值仍是本插件最后写入的值，会恢复到启用前的旧值。
