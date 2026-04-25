# GoGent

GoGent is a Godot 4 editor plugin for AI assisted game development. It adds an editor dock with model configuration, chat, agent management, skill prompts, console commands, a training monitor, and a runtime debug overlay.

## Features

- Multi-provider model configuration for OpenAI-compatible APIs, DeepSeek, OpenRouter, and Ollama.
- Direct Anthropic Claude API support in addition to Claude models through OpenRouter.
- Local Claude Code and Codex CLI bridges for handing a prompt from Godot to external coding agents.
- Chat panel with regular and Server-Sent Events streaming requests.
- Agent system with editable role, system prompt, temperature, max tokens, enabled state, and assigned skills.
- Skill prompt manager for code review, game testing, AI training, game design, deep analysis, and project scaffolding.
- Console commands for listing/selecting models, listing agents, API health checks, scene test launching, and training control.
- Simulated DQN-style training loop with replay buffer, Q-table updates, persisted model snapshots, and live chart rendering.
- Runtime debug overlay with FPS, memory, node counts, scene info, and console command forwarding.
- Headless Godot test script covering managers, model/agent/skill persistence paths, console commands, UI instantiation, and training.

## Installation

Copy `addons/gogent` into a Godot 4 project, then enable `GoGent` in `Project > Project Settings > Plugins`.

This repository also includes a minimal `project.godot` so the plugin can be opened and tested directly.

## Usage

1. Open the GoGent dock in the editor.
2. Go to `Settings`, choose the current provider, and save the API key/base URL.
3. Use `Chat` for normal or streaming AI requests.
4. Use `Agents` to create or edit specialized assistants.
5. Use `Console` for commands such as:

```text
help
list_models
select_model 0 0
list_agents
api_test
external_status
claude review the current Godot scene structure
codex inspect this project and suggest tests
train 100
stop_train
run_test res://path/to/scene.tscn
```

## Claude And Codex Links

GoGent supports Claude and Codex in two ways:

- `Anthropic Claude` appears as a model provider. Add an Anthropic API key in `Settings`, select a Claude model in the chat model picker, and send normal chat requests.
- `Claude Code CLI` and `Codex CLI` can be configured in `Settings`. The defaults are `claude -p {prompt}` and `codex exec {prompt}`. Use `Check Claude`, `Check Codex`, or the `external_status` console command to verify availability.

The CLI bridge sends the current Godot project path as context. If your tools are installed outside `PATH`, set the full executable path in `Settings`.

## Testing

Run the core and UI smoke tests with Godot:

```powershell
..\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests\gogent_core_test.gd
```

To verify editor plugin loading:

```powershell
..\Godot_v4.6.2-stable_win64_console.exe --headless --editor --quit --path .
```

## Notes

- Runtime configuration is written to `addons/gogent/config/*.json`, which is intentionally ignored by Git so API keys are not committed.
- `参考文件` is a local reference folder and is not required by the plugin.
- The plugin uses only GDScript and built-in Godot APIs.
