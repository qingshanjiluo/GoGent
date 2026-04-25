# 🎮 GoGent 插件 - Godot 导入指南

> **GoGent** 是一款全能型 AI 驱动 Godot 4.x 开发插件，提供 AI 对话、多 Agent 协作、技能系统、AI 训练等功能。

---

## 📋 目录

1. [环境要求](#-环境要求)
2. [下载插件](#-下载插件)
3. [导入 Godot 编辑器](#-导入-godot-编辑器)
4. [启用插件](#-启用插件)
5. [配置 API](#-配置-api)
6. [验证安装](#-验证安装)
7. [常见问题](#-常见问题)

---

## ✅ 环境要求

| 项目 | 要求 |
|------|------|
| **Godot 版本** | Godot 4.2+（推荐 4.3 或 4.4） |
| **Godot 类型** | .NET 版或标准版均可 |
| **网络** | 需要访问 AI API（如 DeepSeek、OpenAI、OpenRouter 等） |
| **磁盘空间** | ~10MB |

> ⚠️ **注意**：GoGent 是 **编辑器插件**（EditorPlugin），需要在 Godot 编辑器中启用，不能直接作为游戏内脚本运行。

---

## 📥 下载插件

### 方式一：从 GitHub 下载（推荐）

1. 访问 GoGent 仓库：https://github.com/qingshanjiluo/GoGent
2. 点击 **"Code"** → **"Download ZIP"**
3. 解压下载的 ZIP 文件

### 方式二：使用 Git Clone

```bash
git clone https://github.com/qingshanjiluo/GoGent.git
```

### 方式三：手动复制

如果你已经有插件文件，确保目录结构如下：

```
你的项目/
├── addons/
│   └── gogent/
│       ├── plugin.cfg
│       ├── gogent_plugin.gd
│       ├── core/
│       │   ├── agent_manager.gd
│       │   ├── api_manager.gd
│       │   ├── config_manager.gd
│       │   ├── console_manager.gd
│       │   ├── debug_overlay.gd          # 游戏内实时调试工具
│       │   ├── gogent_singleton.gd
│       │   ├── model_manager.gd
│       │   ├── skill_manager.gd
│       │   ├── stream_manager.gd         # 流式 API 响应 (SSE)
│       │   ├── training_manager.gd
│       │   └── training_visualizer.gd    # 训练可视化图表
│       ├── ui/
│       │   ├── main_panel.gd
│       │   ├── main_panel.tscn
│       │   ├── agent_editor/
│       │   │   ├── agent_editor_panel.gd     # 自定义 Agent 创建 UI
│       │   │   └── agent_editor_panel.tscn
│       │   └── chat/
│       │       ├── message_item.gd
│       │       └── message_item.tscn
│       ├── skills/
│       └── config/
```

---

## 📂 导入 Godot 编辑器

### 步骤 1：打开你的 Godot 项目

启动 Godot 编辑器，打开你要使用 GoGent 插件的项目（或创建一个新项目）。

![打开项目](https://docs.godotengine.org/en/stable/_images/project_manager.png)

### 步骤 2：定位项目目录

在文件资源管理器中找到你的 Godot 项目文件夹。项目文件夹应包含 `project.godot` 文件。

### 步骤 3：复制插件文件

将 `addons/gogent/` 整个文件夹复制到你的 Godot 项目根目录下的 `addons/` 文件夹中。

最终目录结构应如下：

```
你的 Godot 项目/
├── project.godot
├── addons/
│   └── gogent/          ← 复制到这里
│       ├── plugin.cfg
│       ├── gogent_plugin.gd
│       └── ...
├── scenes/
├── scripts/
└── ...
```

> 💡 **提示**：如果项目中没有 `addons/` 文件夹，请手动创建。

---

## 🔌 启用插件

### 步骤 1：打开插件设置

在 Godot 编辑器中，点击顶部菜单栏的 **"项目" (Project)** → **"项目设置" (Project Settings)**。

![项目设置菜单](https://docs.godotengine.org/en/stable/_images/project_settings_menu.png)

### 步骤 2：切换到插件选项卡

在弹出的窗口中，点击 **"插件" (Plugins)** 选项卡。

![插件选项卡](https://docs.godotengine.org/en/stable/_images/plugins_tab.png)

### 步骤 3：启用 GoGent 插件

在插件列表中找到 **GoGent**，点击右侧的 **"启用" (Enable)** 开关，将其设置为 **"开启" (On)**。

![启用插件](https://docs.godotengine.org/en/stable/_images/enable_plugin.png)

### 步骤 4：确认启用成功

启用后，你会看到 Godot 编辑器右侧出现 GoGent 面板，同时输出窗口会显示：

```
=== GoGent 插件初始化中... ===
[GoGent] 已创建 4 个默认供应商
[GoGent] 已创建 4 个默认 Agent
[GoGent] 已创建 6 个默认技能
[GoGent] 所有模块加载完成
=== GoGent 插件初始化完成！ ===
```

![GoGent 面板](https://via.placeholder.com/400x600/1a1a2e/42ffc2?text=GoGent+Panel)

---

## ⚙️ 配置 API

GoGent 需要配置 AI API 才能正常工作。支持以下供应商：

| 供应商 | 类型 | 是否需要 API Key | 备注 |
|--------|------|-----------------|------|
| **DeepSeek** | 在线 | ✅ 是 | 默认推荐，性价比高 |
| **OpenAI** | 在线 | ✅ 是 | GPT-4o 等模型 |
| **OpenRouter** | 聚合 | ✅ 是 | 可调用 Claude、Gemini 等 |
| **Ollama** | 本地 | ❌ 否 | 需要本地安装 Ollama |

### 配置步骤

#### 方法一：通过 GoGent 设置面板

1. 在 GoGent 面板中点击 **"设置" (Settings)** 选项卡
2. 填写以下信息：
   - **API Key**：你的 API 密钥
   - **API URL**：API 基础地址（如 `https://api.deepseek.com`）
   - **代理主机**：（可选）HTTP 代理地址
   - **代理端口**：（可选）HTTP 代理端口
3. 点击 **"保存设置"**

#### 方法二：直接编辑配置文件

打开项目目录下的 `addons/gogent/config/models.json` 文件，编辑供应商配置：

```json
{
  "current_supplier_id": "your_supplier_id",
  "current_model_id": "your_model_id",
  "supplier": [
    {
      "id": "supplier_1",
      "name": "DeepSeek",
      "base_url": "https://api.deepseek.com",
      "api_key": "sk-your-api-key-here",
      "provider": "deepseek",
      "models": [
        {
          "id": "model_1",
          "name": "DeepSeek Chat",
          "model_name": "deepseek-chat",
          "max_tokens": 65536,
          "active": true
        }
      ]
    }
  ]
}
```

### 获取 API Key

- **DeepSeek**：https://platform.deepseek.com/api_keys
- **OpenAI**：https://platform.openai.com/api-keys
- **OpenRouter**：https://openrouter.ai/keys
- **Ollama**：无需 API Key，从 https://ollama.ai 下载安装

---

## ✅ 验证安装

### 1. 检查面板显示

确认 Godot 编辑器右侧出现 GoGent 面板，包含以下选项卡：
- 💬 **聊天** - AI 对话（支持流式/非流式）
- 🖥️ **控制台** - 调试命令
- 🧠 **训练** - AI 训练监控（含实时图表）
- 🤖 **Agent** - 自定义 Agent 创建与管理
- ⚙️ **设置** - 插件配置

### 2. 测试 API 连接

在 **控制台** 选项卡中输入以下命令：

```
api_test
```

如果配置正确，会显示 "API 测试请求已发送"。

### 3. 发送测试消息

1. 切换到 **聊天** 选项卡
2. 在输入框中输入 "你好"
3. 按 **Enter** 发送
4. 等待 AI 回复

---

## ❓ 常见问题

### Q: 启用插件后没有显示面板？

**可能原因**：
- Godot 版本过低（需要 4.2+）
- 插件文件未正确复制到 `addons/` 目录
- 插件依赖的脚本有语法错误

**解决方法**：
1. 检查 Godot 版本：`帮助 → 关于 Godot`
2. 确认文件结构完整
3. 查看编辑器输出面板（Output）中的错误信息

### Q: API 请求失败？

**可能原因**：
- API Key 未配置或配置错误
- 网络连接问题（需要科学上网）
- API 供应商服务异常

**解决方法**：
1. 在设置中重新输入 API Key
2. 配置 HTTP 代理（设置中的代理主机/端口）
3. 在控制台执行 `api_test` 测试连接

### Q: 如何配置代理？

在 GoGent 设置面板中填写：
- **代理主机**：`127.0.0.1`
- **代理端口**：`7890`（或其他代理端口）

或在系统环境变量中设置：
```bash
# Windows PowerShell
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"
```

### Q: 插件与我的其他插件冲突？

GoGent 使用 `GoGent` 作为类名前缀，与大多数插件兼容。如果遇到冲突：
1. 暂时禁用其他插件测试
2. 检查是否有类名重复（如 `APIManager`、`ConfigManager` 等通用名称）

### Q: 如何更新插件？

1. 从 GitHub 下载最新版本
2. 备份你的配置文件（`addons/gogent/config/` 目录）
3. 替换 `addons/gogent/` 目录
4. 恢复配置文件
5. 重启 Godot 编辑器

### Q: 如何卸载插件？

1. 进入 **项目 → 项目设置 → 插件**
2. 将 GoGent 设置为 **"禁用"**
3. （可选）删除 `addons/gogent/` 目录

---

## 🔗 相关资源

- [GoGent GitHub 仓库](https://github.com/qingshanjiluo/GoGent)
- [Godot 官方文档 - 插件系统](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/index.html)
- [Godot 官方文档 - 创建插件](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html)

---

## 📝 许可证

GoGent 基于 MIT 许可证开源。详见项目中的 LICENSE 文件。

---

*让 Godot 开发更智能 — GoGent Team*
