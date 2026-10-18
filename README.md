# HexElim（六角消除）

Godot 4.7 / GDScript / 2D。当前版本为 **0.1.5，优化消除与收拢的流畅度**。

旋转中心六边形，接住四种颜色的方块，让至少三个同色方块相连并消除。在六边各十层的空间内持续生存，通过连续消除提高得分。

## 立即试玩

- **Windows：** 双击 `builds/HexElim.exe`，点击“开始游戏”或按空格。
- **Godot：** 导入根目录的 `project.godot`，按 F5 运行。
- 第一波在开始后的 2 秒生成，左下角显示倒计时。

默认窗口为 **1600×900**，可拖动边框放大或最大化。棋盘、文字和按钮一起等比例缩放；不同屏幕比例会留黑边，保持六边形形状。按 **F11 / Alt+Enter** 切换全屏，退出后恢复原来的窗口大小、位置或最大化状态。

Godot 的 F5 嵌入预览由项目自带的 **HexElim Debug Preview** 编辑器插件配置。加载项目和运行前，插件会把正在使用的预览切换为 **Stretch to Fit（适应窗口）**，最大化预览后棋盘与界面一起放大。更新前已经打开 Godot 时，需重新打开项目以加载新插件。该插件随源码保存，不再依赖手动修改 `.godot/` 缓存文件。

如果手动关闭了插件，可在游戏预览右上角的窗口菜单中选择 Stretch to Fit；Fixed Size（固定尺寸）会固定游戏视口。菜单说明见 [Godot 嵌入游戏说明](https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html)。

## 操作

| 按键 | 功能 |
| --- | --- |
| A | 逆时针旋转 60° |
| D | 顺时针旋转 60° |
| 按住 S | 下落移动速度变为 4 倍；松开恢复 |
| P / Esc | 暂停或继续；暂停同时冻结生成、运动和计分窗口 |
| R | 重新开始一局 |
| 空格 / Enter | 开始游戏、结束后重开，或暂停时继续 |
| M | 音效开关；也可点击右上角按钮 |
| F11 / Alt+Enter | 全屏与窗口切换；游玩时也可点击右上角按钮 |

A/D 每次按下执行一步，旋转动画约 0.14 秒；动画进行中不接受额外转动。在转动完成后落定方块，保证画面朝向与实际落点一致。

## 当前玩法

- 六个下落方向固定；中心六边形和已落定的方块一起旋转。
- 每波随机 1–6 块，来向不重复，四种颜色等概率。
- 同边相邻层，以及相邻两边的同一层互相连接；第 6 边与第 1 边也相邻。只碰角点不连接。
- 至少三个同色方块构成连通组即可消除。同次落定产生的所有合格组合并结算一次；收拢后产生的新组作为下一次连锁结算。
- 消除后，外层方块用约 0.14 秒平滑收拢，空中方块持续下落。未受影响的边可正常接块，正在收拢的边在动画完成后接块，避免穿插。
- 每边可以保留 10 块；下一块到达时无空位则游戏结束。第 10 块若能触发消除，可正常腾出空间。
- 当前“会话最佳”在本次启动中保留，关闭游戏后重置。

## 计分与难度

```text
本次分数 = 6 × 本次消除块数 × 连续消除次数
```

首次次数为 1，每次在前一次消除后的 4 秒内续上，次数加 1，并重新开启完整的 4 秒窗口。窗口到期，下一次从 1 开始。例如连续消除三次、每次三块，分别得到 **18、36、54** 分。

```text
档位 = floor(总分 / 1000)
生成间隔 = max(1.0, 2.0 - 0.1 × 档位) 秒
下落速度 = min(180, 72 + 6 × 档位) 像素/秒
```

生成间隔在安排下一波时更新。S 影响移动速度，不影响生成时钟。速度曲线、4 倍加速、旋转时长等首版数值均集中在 `game/rules/game_rules.gd`，便于试玩后调整。

## 已有功能

- 开始、游玩、暂停、游戏结束与重开流程。
- 旋转接块、随机波次、下落加速、容量判定。
- 同色连通组消除、跨边连接、收拢与连锁。
- 连续计分与窗口倒计时、得分难度提升。
- 中文界面、六边容量提示、危险边提示。
- 旋转动画、消除闪光、粒子与收拢动画。
- 合成的旋转、落定、消除和结束音效。
- 默认窗口 1600×900，1280×720 逻辑画面按窗口等比例缩放，最小窗口 960×540。
- 全屏快捷键与按钮，退出全屏恢复窗口大小、位置或最大化状态。

## 主要文件

```text
project.godot                 项目设置、输入动作、主场景
export_presets.cfg            Windows x86_64 导出预设
icon.svg                      项目图标

game/main.tscn                主场景
game/main.gd                  游戏状态、模拟时钟、输入与玩法协调
game/board/board_model.gd     棋盘数据、邻接匹配、容量与收拢
game/board/board_view.gd      棋盘、来块与动画特效
game/board/board_backdrop.gd  缓存的棋盘背景与网格
game/spawning/wave_generator.gd  可复现种子的随机波次
game/scoring/score_manager.gd 连续计分状态
game/rules/game_rules.gd     规则参数与计分、难度公式
game/ui/game_hud.gd          中文 HUD、菜单与按钮
game/audio/game_audio.gd     合成音效
addons/hexelim_debug_preview/  编辑器内的 F5 预览缩放配置

tests/test_scoring.gd        计分与时间窗口测试
tests/test_gameplay.gd       棋盘与完整玩法流程测试
tests/test_display.gd        实际窗口缩放、鼠标对齐与全屏测试
tests/benchmark_clears.gd    实际渲染的连续大批消除压力测试
docs/game_design.md          当前规则和实现说明
docs/playtest_review.md      试玩审查指南
```

## 验证

已使用本机 Godot 4.7.2 验证计分、棋盘邻接、旋转落点、随机生成、加速、连锁、容量、暂停和重开；还模拟了持续运行直到自然结束的完整对局。

已实际渲染开始、游玩、暂停和结束四种画面，检查中文显示和布局，并通过引擎输入事件验证鼠标开始/继续/重开、工具栏暂停以及键盘操作。检查截图和日志保存在被忽略的 `artifacts/` 中。

在项目目录使用 PowerShell 执行测试：

```powershell
$taskGodotExe = 'D:\steamappliance\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $taskGodotExe --headless --path . --script res://tests/test_scoring.gd
& $taskGodotExe --headless --path . --script res://tests/test_gameplay.gd
& $taskGodotExe --path . --audio-driver Dummy --script res://tests/test_display.gd
```

首次在新机器运行命令行测试前，先在编辑器导入项目，或运行一次 `--headless --editor --path . --quit`，注册脚本类与导入图标。

显示测试需要真实桌面窗口，不使用 `--headless`；会短暂切换全屏并保存截图到 `artifacts/`，默认尺寸检查要求桌面能容纳 1600×900 窗口。

消除压力测试以 120 FPS 上限渲染 360 个采样帧，期间反复触发 60 块同时消除，记录粒子峰值、处理耗时及消除时的下落停帧数：

```powershell
& $taskGodotExe --path . --audio-driver Dummy --disable-vsync --max-fps 120 --script res://tests/benchmark_clears.gd
```

结果写入 `artifacts/clear_profile_current.json`；性能数值受设备和运行环境影响，不作为跨设备测试断言。

受限验证环境可能提示无法读取系统根证书、写入 `user://` 缓存；验证日志已保留。这些环境提示没有阻止项目运行、界面渲染或 Windows 导出。测试所用的引擎副本位于被忽略的临时目录，完成后会清理可执行文件和模板。

## 导出 Windows 版本

本机已安装对应版本的导出模板，可以在编辑器中选择“项目 → 导出 → Windows Desktop”，或执行：

```powershell
& $taskGodotExe --headless --path . --export-release 'Windows Desktop' builds/HexElim.exe
```

导出资源嵌入单个可执行文件，`addons/`、`docs/`、`tests/` 和 `artifacts/` 不参与打包。`builds/` 已在版本控制忽略列表中。
