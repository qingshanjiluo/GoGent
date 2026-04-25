# GoGent Godot Import Guide

## Requirements

- Godot 4.2 or newer.
- Network access for online AI providers.
- Optional local Ollama server for local models.

## Import Into Another Project

1. Copy `addons/gogent` into your Godot project root.
2. Open the project in Godot.
3. Go to `Project > Project Settings > Plugins`.
4. Enable `GoGent`.
5. The GoGent dock appears on the right side of the editor.

## Configure API Access

Open the `Settings` tab in the GoGent dock:

- `API Key`: provider key, if required.
- `Base URL`: provider endpoint, for example `https://api.deepseek.com`, `https://api.openai.com`, `https://openrouter.ai/api`, or `http://localhost:11434`.
- `Proxy Host` and `Proxy Port`: optional HTTP/HTTPS proxy settings.
- `Claude Cmd`: command or full path for Claude Code CLI.
- `Codex Cmd`: command or full path for Codex CLI.

Click `Save Settings`. Configuration is stored locally under `addons/gogent/config/` and is ignored by Git.

## Verify Installation

Use the `Console` tab:

```text
help
list_models
list_agents
external_status
train 3
```

For API verification after adding a key:

```text
api_test
```

## Troubleshooting

- If the dock does not appear, confirm `addons/gogent/plugin.cfg` exists and the plugin is enabled.
- If API calls fail, check the current model selection, API key, base URL, and proxy settings.
- If streaming does not show chunks, verify the selected provider supports OpenAI-compatible SSE responses.
- Direct Anthropic Claude chat uses the Anthropic Messages API. If streaming is enabled, GoGent automatically falls back to the regular request path for Anthropic models.
- If `claude` or `codex` is not found, install the relevant CLI or set the full command path in `Settings`.
- If tests scan unrelated local reference projects, place a `.gdignore` file inside that reference folder.
