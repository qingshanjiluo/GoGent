# GoGent Godot 导入指南

## 环境要求

- Godot 4.2 或更新版本。
- 在线模型供应商需要可用网络。
- 如需本地模型，可选安装 Ollama。
- 如需外部代码 Agent，可选安装 Claude Code CLI 和 Codex CLI。

## 导入到其他项目

1. 将 `addons/gogent` 复制到目标 Godot 项目根目录。
2. 用 Godot 打开目标项目。
3. 进入 `Project > Project Settings > Plugins`。
4. 启用 `GoGent`。
5. 右侧 Dock 会出现 GoGent 工作面板。

## 配置 API 与代理

打开 GoGent Dock 的 `Settings` 标签：

- `API Key`：当前模型供应商的密钥。
- `Base URL`：供应商接口地址，例如 `https://api.deepseek.com`、`https://api.openai.com`、`https://openrouter.ai/api`、`https://api.anthropic.com` 或 `http://localhost:11434`。
- `Proxy Host` / `Proxy Port`：可选 HTTP/HTTPS 代理。
- `Claude Cmd`：Claude Code CLI 命令或完整路径。
- `Codex Cmd`：Codex CLI 命令或完整路径。

点击 `Save Settings` 后，配置会保存在 `addons/gogent/config/`。该目录默认被 Git 忽略。

## 验证安装

在 `Console` 标签中执行：

```text
help
list_models
list_agents
external_status
train 3
```

配置 API Key 后可执行：

```text
api_test
```

## 验证场景编辑能力

打开或创建一个场景后，可以在 `Scene` 标签中操作，也可以使用控制台：

```text
editor_info
list_scene_nodes
create_scene res://scenes/demo.tscn Node2D
add_node Node2D . Player
set_node_prop Player position Vector2(64, 128)
attach_script Player res://scripts/player.gd
select_node Player
```

这些命令会直接作用于 Godot 编辑器当前正在编辑的场景。新增节点会设置 `owner`，因此可以被场景保存。

## 验证人机训练

在 `Training` 标签点击 `Start` 启动训练，或用控制台执行：

```text
train 10
feedback [0,0,0,0] 1 2.0 [0,0,0,1] false manual_reward
stop_train
```

人工反馈会写入训练经验池和统计信息，便于后续训练或分析。

## 常见问题

- 如果 Dock 没有出现，请确认 `addons/gogent/plugin.cfg` 存在，并且插件已启用。
- 如果 API 调用失败，请检查当前模型选择、API Key、Base URL 和代理配置。
- 如果流式输出没有分块显示，请确认所选供应商支持 OpenAI 兼容 SSE 响应。
- Anthropic Claude 直连使用 Anthropic Messages API。选择 Anthropic 模型时，插件会自动使用普通请求路径。
- 如果 `claude` 或 `codex` 未找到，请安装对应 CLI，或在 `Settings` 中填写完整命令路径。
- 如果 Godot 测试扫描到本地参考项目，请在参考目录中放置 `.gdignore`。
