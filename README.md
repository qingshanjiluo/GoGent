# GoGent

GoGent is a Godot 4 editor plugin for AI assisted game development. It adds an editor dock with model configuration, chat, agent management, skill prompts, console commands, a training monitor, and a runtime debug overlay.

## Features

- Multi-provider model configuration for OpenAI-compatible APIs, DeepSeek, OpenRouter, and Ollama.
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
train 100
stop_train
run_test res://path/to/scene.tscn
```

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
