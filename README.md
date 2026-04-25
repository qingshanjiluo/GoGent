<p align="center">
  <img src="https://img.shields.io/badge/Godot-4.x-478cbf?style=for-the-badge&logo=godotengine&logoColor=white" alt="Godot 4.x">
  <img src="https://img.shields.io/badge/GDScript-Plugin-42ffc2?style=for-the-badge&logo=godotengine&logoColor=white" alt="GDScript Plugin">
  <img src="https://img.shields.io/badge/AI-Agent-ffb373?style=for-the-badge&logo=openai&logoColor=white" alt="AI Agent">
  <img src="https://img.shields.io/badge/RL-Training-ff7085?style=for-the-badge&logo=tensorflow&logoColor=white" alt="RL Training">
</p>

<h1 align="center">🚀 GoGent</h1>
<p align="center"><b>让 Godot 开发更智能 — 全能型 AI 驱动 Godot 开发插件</b></p>

<p align="center">
  <a href="#-核心功能">核心功能</a> •
  <a href="#-快速开始">快速开始</a> •
  <a href="#-模块架构">模块架构</a> •
  <a href="#-agent-协作">Agent 协作</a> •
  <a href="#-api-链接与技能系统">API 与技能</a> •
  <a href="#-ai-训练">AI 训练</a> •
  <a href="#-控制台与调试">控制台</a> •
  <a href="#-参考项目">参考项目</a>
</p>

---

## 📖 简介

**GoGent** 是一个基于 Godot 4.x 的全能型 AI 驱动开发插件，它将 AI Agent 协作、多模型 API 集成、强化学习训练、控制台调试等功能整合到一个统一的编辑器中，让 Godot 游戏开发效率大幅提升。

> 核心参考项目：[AlphaAgent-master](参考文件/AlphaAgent-master)

### ✨ 设计理念

- **🤖 AI 原生集成** — 将 AI 能力深度嵌入 Godot 编辑器工作流
- **🔌 多模型支持** — 兼容 OpenAI、DeepSeek、Claude（OpenRouter）、Ollama 等多种 API
- **🧩 模块化架构** — 各功能模块独立设计，易于扩展和维护
- **🎮 游戏开发专精** — 所有功能围绕 Godot 游戏开发场景优化

---

## 🎯 核心功能

| 功能 | 描述 |
|------|------|
| **🤝 Agent 协作** | 多角色 AI Agent 协同工作，共同解决复杂开发问题 |
| **🔗 API 链接** | 通过 Skill 系统与 Claude、GPT、DeepSeek 等 AI 模型无缝对接 |
| **🖥️ 控制台调试** | 内置命令系统，支持场景测试、API 测试、模型管理等 |
| **🧠 AI 训练** | DQN 强化学习框架，支持人机对抗训练与模型持久化 |
| **📋 技能系统** | 预置代码审查、游戏测试、AI 训练、游戏设计等专业技能 |
| **⚙️ 灵活配置** | 多供应商模型管理、代理设置、自定义参数 |

---

## 🚀 快速开始

### 安装

1. 将 `addons/gogent` 目录复制到你的 Godot 项目根目录
2. 打开 Godot → **项目设置** → **插件** → 启用 **GoGent**
3. 在编辑器右侧面板即可看到 GoGent 主界面

### 配置 API

1. 点击 **⚙️ 设置** Tab
2. 输入你的 API Key 和 API URL
3. 点击 **保存设置**

> **默认支持的供应商：**
> - [OpenAI](https://platform.openai.com) — GPT-4o 等
> - [DeepSeek](https://platform.deepseek.com) — DeepSeek Chat/Reasoner
> - [OpenRouter](https://openrouter.ai) — Claude Sonnet 4.5 等
> - [Ollama](http://localhost:11434) — 本地模型

### 快速使用

```bash
# 在控制台中测试 API 连接
> api_test

# 列出所有可用模型
> list_models

# 列出所有 Agent
> list_agents

# 运行指定场景测试
> run_test res://your_scene.tscn

# 启动 AI 训练
> train 100

# 查看对话历史与项目文件
> chat_history
> list_files res://
> read_file res://project.godot

# 导入 Skill ZIP
> import_skill_zip C:/path/to/skills.zip

# 调用外部 Agent
> claude review this Godot project
> codex inspect current implementation
```

---

## 🏗️ 模块架构

```
addons/gogent/
├── plugin.cfg                        # 插件配置
├── gogent_plugin.gd                  # 主插件入口 (EditorPlugin)
├── core/                             # 核心模块
│   ├── gogent_singleton.gd           # 全局单例 (状态管理/信号)
│   ├── config_manager.gd             # 配置管理 (JSON 持久化)
│   ├── model_manager.gd              # 模型/供应商管理
│   ├── api_manager.gd                # API 通信层 (OpenAI 兼容)
│   ├── agent_manager.gd              # Agent 管理与协作引擎
│   ├── console_manager.gd            # 控制台与命令系统
│   ├── conversation_manager.gd       # 对话历史保存与加载
│   ├── workspace_tool_manager.gd     # 项目文件读写/搜索工具
│   ├── node_editor_manager.gd        # Godot 场景与节点编辑工具
│   ├── external_tool_manager.gd      # Claude Code / Codex CLI 链接
│   ├── stream_manager.gd             # SSE 流式响应处理
│   ├── training_manager.gd           # 强化学习训练框架
│   └── skill_manager.gd              # 技能系统 (提示模板引擎)
├── ui/                               # 用户界面
│   ├── main_panel.gd                 # 主面板逻辑
│   ├── main_panel.tscn               # 主面板场景
│   └── chat/
│       ├── message_item.gd           # 消息项组件
│       └── message_item.tscn         # 消息项场景
└── skills/                           # 技能文件目录
```

### 数据流

```
用户输入 → UI 主面板 → 对话历史管理器 → API 管理器 → AI 模型 (OpenAI/DeepSeek/Claude...)
                ↓                         ↓
         Agent 管理器 ←→ 技能系统       RooCode 风格工具调用
                ↓                         ↓
         控制台管理器 / 训练管理器 / 场景节点工具 / 项目文件工具 / Claude-Codex 外部 Agent
```

---

## 🤝 Agent 协作

GoGent 内置 4 个专业 AI Agent，可协同解决复杂开发任务：

| Agent | 角色 | 专长 |
|-------|------|------|
| **代码助手** | Godot 开发专家 | GDScript 编写、代码优化、Bug 修复 |
| **策划助手** | 游戏策划专家 | 游戏设计、数值平衡、关卡规划 |
| **测试助手** | QA 测试专家 | 测试用例、性能分析、Bug 追踪 |
| **AI 训练师** | 机器学习专家 | 强化学习、神经网络训练 |

### 协作模式

1. 在输入框中输入问题
2. 点击 **🤝 协作** 按钮
3. 所有启用的 Agent 将同时收到任务
4. 每个 Agent 根据自身角色给出专业建议

---

## 🔗 API 链接与技能系统

### 技能系统

技能是预定义的提示模板，用于与 AI 模型进行特定任务的交互：

| 技能 | 用途 | 目标模型 |
|------|------|----------|
| **代码审查** | 审查 GDScript 代码质量 | GPT-4o / DeepSeek |
| **游戏测试** | 生成测试方案和脚本 | GPT-4o |
| **AI 训练** | 配置训练参数和策略 | DeepSeek |
| **游戏设计** | 策划和设计建议 | Claude (OpenRouter) |
| **深度分析** | 多角度深度代码分析 | Claude Sonnet |
| **项目脚手架** | 生成项目结构和模板 | GPT-4o |

### 支持的 API 供应商

```
OpenAI      → https://api.openai.com/v1
DeepSeek    → https://api.deepseek.com/v1
OpenRouter  → https://openrouter.ai/api/v1 (Claude/GPT 等)
Ollama      → http://localhost:11434/v1 (本地模型)
```

---

## 🧠 AI 训练

基于 DQN（Deep Q-Network）算法的强化学习训练框架：

### 特性

- **经验回放缓冲区** — 存储和采样训练经验
- **ε-贪心探索** — 平衡探索与利用
- **探索率衰减** — 训练过程中逐步降低探索率
- **模型持久化** — 支持训练过程中的自动保存和加载
- **实时监控** — 训练进度、奖励曲线、探索率可视化

### 训练流程

```
初始化环境 → 重置状态 → 选择动作 → 执行动作
    ↑                              ↓
    └── 存储经验 ← 获取奖励 ← 更新状态
           ↓
        批量采样 → 训练网络 → 更新权重
```

---

## 🖥️ 控制台与调试

内置命令系统，支持丰富的调试操作：

| 命令 | 参数 | 说明 |
|------|------|------|
| `help` | - | 显示所有可用命令 |
| `clear` | - | 清除控制台输出 |
| `echo` | `<text>` | 输出文本 |
| `list_agents` | - | 列出所有 Agent |
| `list_models` | - | 列出所有模型供应商 |
| `run_test` | `<scene_path>` | 在编辑器中运行指定场景 |
| `train` | `<episodes>` | 启动 AI 训练 |
| `api_test` | - | 测试 API 连接 |
| `godot` | `<command>` | 执行 Godot 编辑器命令 |

---

## 📚 参考项目

GoGent 在开发过程中参考了以下优秀开源项目：

| 项目 | 参考内容 |
|------|----------|
| [AlphaAgent-master](参考文件/AlphaAgent-master) | 🏆 **核心参考** — 插件架构、Agent 系统、API 通信 |
| [Microverse-main](参考文件/Microverse-main) | 多 Agent 协作、对话管理、API 管理器 |
| [GodoLM-main](参考文件/GodoLM-main) | 自定义资源类型、模型配置 |
| [MLGodotKit-main](参考文件/MLGodotKit-main) | 神经网络、矩阵运算、强化学习 |
| [godot_rl_agents-main](参考文件/godot_rl_agents-main) | Python-Godot RL 训练框架 |
| [Utility_AI_GDExtension-main](参考文件/Utility_AI_GDExtension-main) | AI 行为决策系统 |
| [limboai-master](参考文件/limboai-master) | 行为树 GDExtension |
| [local-llm-npc-main](参考文件/local-llm-npc-main) | 本地 LLM NPC 集成 |
| [nobodywho-main](参考文件/nobodywho-main) | 本地 AI 推理引擎 |
| [web-access-main](参考文件/web-access-main) | Web 访问工具 |

---

## 🗺️ 开发路线图

- [x] 核心模块架构设计
- [x] 多模型 API 集成
- [x] Agent 协作系统
- [x] 控制台与命令系统
- [x] DQN 训练框架
- [x] 技能系统
- [x] UI 主面板
- [ ] 流式 API 响应 (SSE)
- [ ] 游戏内实时调试工具
- [ ] 训练可视化图表
- [ ] 自定义 Agent 创建 UI
- [ ] 技能市场 (社区共享)
- [ ] 多语言支持

---

## 💬 支持与反馈

- 如有问题，请 [提交 Issue](https://github.com/qingshanjiluo/GoGent/issues)
- 作者：**最中幻想**
- 微信：`andyloveanny`
- 邮箱：[sifangzhiji@qq.com](mailto:sifangzhiji@qq.com)

### ☕ 赞助支持

如果这个项目对你有帮助，欢迎请作者喝一杯咖啡，谢谢 ＾3＾

<p align="left">
  <img src="https://chat.mk49.cyou/static/files/68a2d748ad67a2438ad9e49b/9b8157ca091035857751b6c61028e9e3.jpg" alt="赞助二维码" width="200" style="border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
</p>

### 🔗 友情链接

- [GitHub 仓库](https://github.com/qingshanjiluo/GoGent.git)
- [MK48 论坛](http://mk48by049.mbbs.cc)
- [China Free MBBS](http://china.free.mbbs.ss)
- [Kimi 智能助手](https://kimi.com)
- [文叔叔 - 文件传输](https://wenshushu.cn)
- [AirPortal - 快传](https://airportal.cn)

---

<p align="center">
  Made with ❤️ by <b>最中幻想</b>
  <br>
  <sub>GoGent — 让 Godot 开发更智能</sub>
</p>
