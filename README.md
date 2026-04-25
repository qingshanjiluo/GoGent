# GoGent

GoGent 是一个面向 Godot 4 编辑器的 AI 辅助开发插件。它把 AI 对话、Agent 集群、场景节点编辑、OpenAI 兼容 API、DeepSeek、Claude/Codex 连接、人机训练和调试控制台集中到 Godot 编辑器侧边栏中。

## 核心能力

- AI 对话：支持普通请求和 OpenAI 兼容 SSE 流式响应。
- 模型供应商：内置 DeepSeek、OpenAI、OpenAI 兼容接口、Anthropic Claude、OpenRouter 和 Ollama。
- 丰富 AI 参数：可在插件设置页调整接口类型、模型名、模型能力、temperature、top_p、max_tokens、presence_penalty、frequency_penalty、JSON 输出模式、工具参数开关、推理适配和请求超时。
- Claude/Codex 连接：可直连 Anthropic Claude API，也可把任务转交给本地 Claude Code CLI 或 Codex CLI。
- Agent 集群：内置代码工程师、场景编辑师、游戏策划、测试工程师、AI 训练师等角色，并支持自定义 Agent。
- 场景编辑：AI 不只写代码，也能通过 GoGent 创建场景、列出节点、添加节点、编辑节点属性、选中节点、删除节点、挂载脚本。
- 技能系统：内置代码审查、游戏测试、AI 训练、游戏设计、深度分析和项目脚手架等提示模板。
- 人机训练：内置 DQN 风格训练循环、经验回放、Q 表更新、模型保存、训练曲线，并支持人工奖励反馈写入经验池。
- 控制台：提供模型管理、AI 参数设置、API 测试、外部工具检查、场景编辑、训练控制和运行场景等命令。
- 调试覆盖层：可显示 FPS、内存、节点数量、场景信息，并转发控制台命令。

## 安装

1. 将 `addons/gogent` 复制到 Godot 4 项目根目录。
2. 打开 Godot。
3. 进入 `Project > Project Settings > Plugins`。
4. 启用 `GoGent`。
5. 右侧 Dock 会出现 GoGent 工作面板。

本仓库自带最小 `project.godot`，可直接作为插件开发和测试项目打开。

## 设置模型与 API

进入 `Settings` 标签：

- `接口类型`：选择 `DeepSeek`、`OpenAI`、`OpenAI 兼容`、`Anthropic Claude` 或 `Ollama`。
- `API Key`：填写当前供应商密钥。本地 Ollama 通常可以留空。
- `Base URL`：填写接口根地址，例如 `https://api.deepseek.com`、`https://api.openai.com`、`https://api.anthropic.com`、`https://openrouter.ai/api`、`http://localhost:11434`。
- `显示名称` / `模型名`：编辑当前模型展示名和真实请求模型名。
- `模型上限`：当前模型的最大输出 token 上限。
- `温度`、`Top P`、`输出上限`、`存在惩罚`、`频率惩罚`：会直接进入 OpenAI 兼容请求体。
- `JSON 输出模式`：为 OpenAI 兼容接口添加 `response_format: {"type":"json_object"}`。
- `启用推理内容适配`：为支持推理内容的模型保留 reasoning 解析和 OpenRouter 适配。
- `允许工具参数`：允许请求携带工具调用配置。
- `超时秒数`：控制 Godot `HTTPRequest` 超时时间。
- `Proxy Host` / `Proxy Port`：可选代理。
- `Claude Cmd` / `Codex Cmd`：本地 Claude Code 和 Codex CLI 命令。

保存后配置会写入 `addons/gogent/config/`。该目录默认被 Git 忽略，避免提交 API Key。

## 使用 Agent

GoGent 内置多个 Agent：

- `代码工程师`：负责 GDScript、编辑器插件、调试和代码质量。
- `场景编辑师`：负责场景结构、节点创建、属性编辑和脚本挂载。
- `游戏策划`：负责玩法、数值、关卡和玩家体验。
- `测试工程师`：负责测试计划、边界条件、自动化测试和 Bug 复现。
- `AI 训练师`：负责状态、动作、奖励、人工反馈和训练评估。

Agent 的系统上下文会包含可用的 GoGent 场景命令、AI 设置命令和训练反馈命令，因此它们可以给出更具体的 Godot 编辑器操作方案。

## 场景节点编辑

可以使用 `Scene` 标签，也可以在 `Console` 中执行：

```text
editor_info
list_scene_nodes
list_scene_nodes res://scenes/main.tscn
create_scene res://scenes/demo.tscn Node2D
add_node CharacterBody2D . Player
add_node Camera2D Player Camera
set_node_prop Player position Vector2(128, 256)
set_node_prop Player name "Hero"
select_node Player
attach_script Player res://scripts/player.gd
delete_node Player/Camera
```

`set_node_prop` 的值会先使用 Godot `str_to_var` 解析。字符串建议写成 `"Hero"`，向量可写成 `Vector2(10, 20)`。

## 常用控制台命令

```text
help
list_models
select_model 0 0
ai_settings
set_ai_option temperature 0.55
set_ai_option json_mode true
list_agents
api_test
external_status
claude review the current Godot scene structure
codex inspect this project and suggest tests
train 100
stop_train
feedback [0,0,0,0] 1 1.0 [0,0,0,1] false good_action
run_test res://path/to/scene.tscn
```

## Claude 与 Codex

GoGent 支持两种连接方式：

- 作为模型供应商使用：选择 `Anthropic Claude`，填写 API Key 后直接在 `Chat` 中对话。
- 作为本地外部 Agent 使用：在 `Settings` 中配置 `Claude Cmd` 和 `Codex Cmd`，然后点击 `Claude CLI`、`Codex CLI` 或使用控制台命令。

外部 CLI 调用会把当前 Godot 项目路径作为上下文传入。如果工具不在 `PATH` 中，请填写完整可执行文件路径。

## 人机训练

`Training` 标签可启动训练并记录人工反馈。人工反馈会写入训练管理器的 `human_feedback` 列表和经验回放池。

控制台格式：

```text
feedback <state_json> <action> <reward> [next_state_json] [done] [note]
```

示例：

```text
feedback [0.1,0.2,0.3,0.4] 2 3.5 [0.2,0.2,0.3,0.4] false player_reached_goal
```

## 测试

运行核心和 UI 冒烟测试：

```powershell
..\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests\gogent_core_test.gd
```

验证编辑器插件加载：

```powershell
..\Godot_v4.6.2-stable_win64_console.exe --headless --editor --quit --path .
```

## 项目结构

```text
addons/gogent/
├── gogent_plugin.gd
├── plugin.cfg
├── core/
│   ├── agent_manager.gd
│   ├── api_manager.gd
│   ├── config_manager.gd
│   ├── console_manager.gd
│   ├── external_tool_manager.gd
│   ├── gogent_singleton.gd
│   ├── model_manager.gd
│   ├── node_editor_manager.gd
│   ├── skill_manager.gd
│   ├── stream_manager.gd
│   └── training_manager.gd
└── ui/
    ├── main_panel.gd
    ├── main_panel.tscn
    └── chat/
```

## 说明

- `参考文件` 是本地参考项目目录，不是插件运行依赖。
- 插件使用 GDScript 和 Godot 内置 API 实现。
- README 和主要新增注释使用中文，便于后续维护。
