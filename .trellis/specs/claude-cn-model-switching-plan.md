# cc-switch 支持 claude-cn 模型切换技术方案

## 1. 目标

本方案用于指导在 `farion1231/cc-switch` 的 fork 中新增一个独立应用类型 `claude-cn`，用于替代本地 `cc-model` 项目的“切模型”能力。

最终目标：

1. 在 cc-switch 中同时保留原生 Claude Code 应用槽位 `claude` 和新增应用槽位 `claude-cn`。
2. `claude` 切换 provider 时只写入原生 Claude Code 配置目录，默认 `~/.claude/settings.json`。
3. `claude-cn` 切换 provider 时只写入第二套 Claude Code 配置目录，默认 `~/.claude-cn/settings.json`。
4. 两个应用槽位的 provider 列表、当前 provider、配置目录覆盖互相独立。
5. `claude-cn` 复用 cc-switch 现有 Claude Code provider 表单、配置结构、模型字段和写入逻辑。
6. 第一阶段只覆盖 `cc-model` 的模型切换能力，不做完整进程管理、不做 API 批量测速、不做 CLI TUI 复刻。

## 2. 非目标

本次明确不处理以下内容：

1. 不实现 `cc-model processes` 的 Claude 进程查看和 kill 能力。
2. 不实现 `cc-model test` 的 API 连通性批量测试能力。
3. 不复刻 `cc-model` 的终端交互 UI。
4. 不强制实现 `~/.claude-cn/profiles.json` 自动迁移；可作为后续增强。
5. 不在第一阶段完整扩展 MCP、Skills、Prompt 到 `claude-cn`。如果相关类型编译必须补字段，则只做最小兼容，不提供完整用户入口。
6. 不修改 `claude-cn` CLI 本身。前提是本机 `claude-cn` 已经能读取 `~/.claude-cn/settings.json`。

## 3. 背景

当前本地 `cc-model` 是单文件 Python CLI，核心能力是维护 `~/.claude-cn/profiles.json`，并把选中的 profile 写入 `~/.claude-cn/settings.json`。

`cc-model` 的 profile 字段：

```json
{
  "name": "provider name",
  "base_url": "https://example.com",
  "auth_token": "token",
  "cc_model": "sonnet",
  "api_model": "actual-upstream-model"
}
```

切换时写入的 Claude Code settings 形态：

```json
{
  "model": "sonnet",
  "env": {
    "ANTHROPIC_BASE_URL": "https://example.com",
    "ANTHROPIC_AUTH_TOKEN": "token",
    "ANTHROPIC_MODEL": "actual-upstream-model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "actual-upstream-model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "actual-upstream-model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "actual-upstream-model"
  }
}
```

cc-switch 当前已经有 Claude Code provider 管理能力，并支持以下字段：

```json
{
  "model": "sonnet",
  "env": {
    "ANTHROPIC_BASE_URL": "...",
    "ANTHROPIC_AUTH_TOKEN": "...",
    "ANTHROPIC_API_KEY": "...",
    "ANTHROPIC_MODEL": "...",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "...",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "...",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "..."
  }
}
```

因此 cc-switch 的配置模型与 `cc-model` 的“切模型”能力是兼容的。需要补齐的是第二套 Claude Code 应用槽位和第二套配置路径。

## 4. 现状分析

基于 cc-switch 当前 `main`，相关结构如下：

1. 前端应用 ID 定义在 `src/lib/api/types.ts`，当前包含 `claude`、`claude-desktop`、`codex`、`gemini`、`opencode`、`openclaw`、`hermes`。
2. 前端应用展示配置在 `src/config/appConfig.tsx`，`APP_IDS` 和 `APP_ICON_MAP` 控制主页面 tab。
3. 后端应用枚举在 `src-tauri/src/app_config.rs` 的 `AppType`。
4. cc-switch 的主配置 `MultiAppConfig` 使用 `apps: HashMap<String, ProviderManager>`，新增 app key 的数据结构成本较低。
5. Claude Code 配置目录逻辑在 `src-tauri/src/config.rs`：
   - `get_claude_config_dir()`
   - `get_claude_mcp_path()`
   - `get_claude_settings_path()`
6. 设备级设置在 `src-tauri/src/settings.rs`，当前只有一份：
   - `claude_config_dir`
   - `current_provider_claude`
7. live 写入逻辑在 `src-tauri/src/services/provider/live.rs`，`AppType::Claude` 分支写入 `get_claude_settings_path()`。
8. 配置同步逻辑在 `src-tauri/src/services/config.rs`，当前 `sync_current_providers_to_live()` 同步 `Claude`、`Codex`、`Gemini`。
9. Claude provider 表单在 `src/components/providers/forms/ClaudeFormFields.tsx`，可以直接复用，不应复制一套表单。

关键判断：

1. 新增 `claude-cn` 应走“新增 AppType”路线，而不是把 Claude 配置目录改成 `~/.claude-cn`。
2. `claude-cn` 与 `claude` 应共用 Claude provider 的 JSON 配置结构和写入逻辑。
3. `claude-cn` 的 provider 数据应存储在 cc-switch config/database 的独立 app namespace 中，app id 固定为 `claude-cn`。

## 5. 约束

### 5.1 技术栈约束

1. 前端保持 React + TypeScript + Vite + Tailwind + 现有组件体系。
2. 后端保持 Tauri + Rust。
3. 不新增运行时依赖。
4. 不引入新的状态管理方案。
5. 不新增独立数据库表，复用现有 provider/app namespace 机制。

### 5.2 工程风格约束

1. 复用现有 Claude Code provider 表单和 provider 服务逻辑。
2. 禁止复制一整套 Claude provider 实现。
3. 允许新增小型 helper，例如按 `AppType` 返回 Claude-like settings path。
4. 所有新增分支必须显式处理 `AppType::ClaudeCn`，不能依赖默认分支吞掉。
5. 写入 live settings 必须保持原有 `sanitize_claude_settings_for_live()` 行为。
6. 不改变 `claude` 现有默认路径和行为。
7. 不修改原有 provider 数据 schema，除非为了新增 app id 的兼容。
8. 所有配置路径必须支持用户覆盖目录。

### 5.3 数据兼容约束

1. 旧 cc-switch 配置中没有 `claude-cn` 时，加载后应自动补一个空 `ProviderManager`，不破坏旧配置。
2. 旧配置中的 `claude` providers 不应自动复制到 `claude-cn`。
3. `claude-cn` 当前 provider 应独立保存为 `current_provider_claude_cn`。
4. `claude-cn` 配置目录覆盖应独立保存为 `claude_cn_config_dir`。

### 5.4 安全约束

1. API key/token 只写入对应 Claude Code settings，不写日志。
2. 不在错误信息中输出完整 token。
3. 不把 `claude-cn` 切换写入 `~/.claude/settings.json`。
4. 不把 `claude` 切换写入 `~/.claude-cn/settings.json`。

## 6. 技术设计

### 6.1 新增 AppType

在 `src-tauri/src/app_config.rs` 中新增枚举值：

```rust
pub enum AppType {
    Claude,
    #[serde(rename = "claude-cn", alias = "claude_cn", alias = "claudeCn")]
    ClaudeCn,
    ClaudeDesktop,
    Codex,
    Gemini,
    OpenCode,
    OpenClaw,
    Hermes,
}
```

要求：

1. `as_str()` 返回 `"claude-cn"`。
2. `FromStr` 支持 `"claude-cn"`、`"claude_cn"`、`"claudecn"`。
3. `all()` 包含 `AppType::ClaudeCn`。
4. `is_additive_mode()` 对 `ClaudeCn` 返回 `false`，和 `Claude` 一致。
5. 错误提示中的 allowed app list 加上 `claude-cn`。

### 6.2 前端 AppId 和主页面 tab

修改 `src/lib/api/types.ts`：

```ts
export type AppId =
  | "claude"
  | "claude-cn"
  | "claude-desktop"
  | "codex"
  | "gemini"
  | "opencode"
  | "openclaw"
  | "hermes";
```

修改 `src/config/appConfig.tsx`：

1. 在 `APP_IDS` 中把 `"claude-cn"` 放在 `"claude"` 后面。
2. 在 `APP_ICON_MAP` 中新增：

```ts
"claude-cn": {
  label: "Claude CN",
  icon: <ClaudeIcon size={14} />,
  activeClass: "...",
  badgeClass: "..."
}
```

样式可复用 Claude 的橙色系，也可使用 cyan 区分。第一阶段优先复用现有 Claude 图标，避免新增资产。

### 6.3 配置目录和 settings path

在 `src-tauri/src/settings.rs` 的 `AppSettings` 新增：

```rust
pub claude_cn_config_dir: Option<String>,
pub current_provider_claude_cn: Option<String>,
```

并修改：

1. `Default` 初始化为 `None`。
2. `normalize_paths()` 处理 `claude_cn_config_dir`。
3. 新增 `get_claude_cn_override_dir()`。
4. `get_current_provider()` 对 `AppType::ClaudeCn` 返回 `current_provider_claude_cn`。
5. `set_current_provider()` 对 `AppType::ClaudeCn` 写入 `current_provider_claude_cn`。

在 `src-tauri/src/config.rs` 新增：

```rust
pub fn get_claude_cn_config_dir() -> PathBuf {
    if let Some(custom) = crate::settings::get_claude_cn_override_dir() {
        return custom;
    }
    get_home_dir().join(".claude-cn")
}

pub fn get_claude_cn_settings_path() -> PathBuf {
    get_claude_cn_config_dir().join("settings.json")
}
```

建议新增一个统一 helper：

```rust
pub fn get_claude_like_settings_path(app_type: &AppType) -> Result<PathBuf, AppError> {
    match app_type {
        AppType::Claude => Ok(get_claude_settings_path()),
        AppType::ClaudeCn => Ok(get_claude_cn_settings_path()),
        other => Err(AppError::Config(format!("not a Claude-like app: {}", other.as_str()))),
    }
}
```

如果需要 MCP 路径最小兼容，可新增：

```rust
pub fn get_claude_cn_mcp_path() -> PathBuf {
    get_home_dir().join(".claude-cn.json")
}
```

第一阶段不需要给 UI 暴露 MCP 能力。

### 6.4 MultiAppConfig 默认值和加载补齐

修改 `src-tauri/src/app_config.rs`：

1. `Default for MultiAppConfig` 增加：

```rust
apps.insert("claude-cn".to_string(), ProviderManager::default());
```

2. `MultiAppConfig::load()` 在兼容旧配置时检查并补齐：

```rust
if !config.apps.contains_key("claude-cn") {
    config.apps.insert("claude-cn".to_string(), ProviderManager::default());
    updated = true;
}
```

3. `get_manager()`、`get_manager_mut()`、`ensure_app()` 无需额外改动，因为它们通过 `app.as_str()` 访问。

### 6.5 Claude-like live 写入复用

修改 `src-tauri/src/services/provider/live.rs`。

将当前 `AppType::Claude` 的 live 写入逻辑泛化：

```rust
fn write_claude_like_live_snapshot(app_type: &AppType, provider: &Provider) -> Result<(), AppError> {
    let path = crate::config::get_claude_like_settings_path(app_type)?;
    let settings = sanitize_claude_settings_for_live(&provider.settings_config);
    write_json_file(&path, &settings)?;
    Ok(())
}
```

然后在 `write_live_snapshot()` 中：

```rust
AppType::Claude | AppType::ClaudeCn => {
    write_claude_like_live_snapshot(app_type, provider)?;
}
```

读取 live config 的导入逻辑也应支持 `ClaudeCn`：

```rust
AppType::Claude | AppType::ClaudeCn => {
    let settings_path = get_claude_like_settings_path(app_type)?;
    ...
}
```

注意：

1. `sanitize_claude_settings_for_live()` 必须继续移除内部字段。
2. 写入前必须创建 parent directory。
3. 错误文案中应根据 app id 显示 `Claude Code` 或 `Claude CN`，但第一阶段可以使用通用 “Claude-like settings file is missing”。

### 6.6 配置同步

修改 `src-tauri/src/services/config.rs`：

1. `sync_current_providers_to_live()` 增加：

```rust
Self::sync_current_provider_for_app(config, &AppType::ClaudeCn)?;
```

2. `sync_current_provider_for_app()` 中让 `ClaudeCn` 走 Claude live 同步：

```rust
AppType::Claude | AppType::ClaudeCn => {
    Self::sync_claude_like_live(config, app_type, &current_id, &provider)?;
}
```

3. 将当前 `sync_claude_live()` 改为接收 `app_type`：

```rust
fn sync_claude_like_live(
    config: &mut MultiAppConfig,
    app_type: &AppType,
    provider_id: &str,
    provider: &Provider,
) -> Result<(), AppError>
```

内部：

1. 使用 `get_claude_like_settings_path(app_type)` 获取路径。
2. 写入 sanitized settings。
3. 读回 live settings。
4. 用 `config.get_manager_mut(app_type)` 更新对应 provider 的 `settings_config`。

禁止继续硬编码 `config.get_manager_mut(&AppType::Claude)`，否则 `claude-cn` 切换后会污染 Claude provider。

### 6.7 Provider 服务和校验

修改 `src-tauri/src/services/provider/mod.rs`：

1. `validate_provider_settings()` 中 `ClaudeCn` 和 `Claude` 一样要求 `settings_config` 是 JSON object。
2. `extract_common_config()` 中 `ClaudeCn` 复用 `extract_claude_common_config()`。
3. provider normalize、创建、更新、切换中所有只匹配 `AppType::Claude` 的逻辑，如果语义是 “Claude Code JSON settings”，应扩展为 `AppType::Claude | AppType::ClaudeCn`。
4. 如果某些逻辑语义是 “Claude 官方插件集成” 或 “Claude Desktop 相关”，不要扩展到 `ClaudeCn`。

执行 agent 需要重点搜索：

```bash
rg -n "AppType::Claude|\"claude\"|claude_config_dir|current_provider_claude|get_claude_settings_path|get_claude_config_dir" src-tauri/src src
```

逐处判断是否需要加入 `ClaudeCn`。

### 6.8 前端表单复用

现有 provider 表单应通过 app id 判断显示哪种表单。执行 agent 需要找到路由点，通常会在这些文件附近：

1. `src/components/providers/ProviderList.tsx`
2. `src/components/providers/AddProviderDialog.tsx`
3. `src/components/providers/EditProviderDialog.tsx`
4. `src/components/providers/forms/ProviderForm.tsx`

要求：

1. `activeApp === "claude-cn"` 时使用 Claude provider 表单。
2. API key、base URL、模型映射、fallback model 等字段与 Claude 完全一致。
3. 不新增 `ClaudeCnFormFields.tsx`。
4. 不改变原有 `activeApp === "claude"` 的行为。

### 6.9 设置页目录覆盖

修改 `src/components/settings/DirectorySettings.tsx`：

1. `DirectoryAppId` 应包含 `claude-cn`。
2. Props 增加：

```ts
claudeCnDir?: string;
```

3. 渲染一个新的 `DirectoryInput`：

```tsx
<DirectoryInput
  label={t("settings.claudeCnConfigDir")}
  value={claudeCnDir}
  resolvedValue={resolvedDirs["claude-cn"]}
  placeholder={t("settings.browsePlaceholderClaudeCn")}
  onChange={(val) => onDirectoryChange("claude-cn", val)}
  onBrowse={() => onBrowseDirectory("claude-cn")}
  onReset={() => onResetDirectory("claude-cn")}
/>
```

同步修改 `src/hooks/useSettings.ts` 里的 settings schema、resolved dirs、保存逻辑和 reset/browse 逻辑。

### 6.10 i18n

至少修改：

1. `src/i18n/locales/zh.json`
2. `src/i18n/locales/en.json`
3. `src/i18n/locales/ja.json`

新增文案：

```json
{
  "apps": {
    "claude-cn": "Claude CN"
  },
  "settings": {
    "claudeCnConfigDir": "Claude CN 配置目录",
    "browsePlaceholderClaudeCn": "例如：/home/<你的用户名>/.claude-cn"
  }
}
```

实际 key 需按现有文件结构放置，不要新建孤立 namespace。

## 7. 实施步骤

### Step 1：新增后端 AppType

修改：

1. `src-tauri/src/app_config.rs`
2. 相关 AppType 测试

验证：

1. `AppType::from_str("claude-cn")` 返回 `AppType::ClaudeCn`。
2. `AppType::ClaudeCn.as_str()` 返回 `"claude-cn"`。
3. `AppType::all()` 包含 `ClaudeCn`。

### Step 2：新增 settings 字段和路径函数

修改：

1. `src-tauri/src/settings.rs`
2. `src-tauri/src/config.rs`

验证：

1. 默认 `claude-cn` 配置目录解析为 `~/.claude-cn`。
2. 设置 `claudeCnConfigDir` 后解析到覆盖目录。
3. `current_provider_claude_cn` 不影响 `current_provider_claude`。

### Step 3：补齐 MultiAppConfig

修改：

1. `src-tauri/src/app_config.rs`

验证：

1. 新安装默认 config 包含 `"claude-cn"`。
2. 老 config 加载后自动补齐 `"claude-cn"` 并保存。
3. 老 config 中 `"claude"` providers 不被复制、不被修改。

### Step 4：泛化 Claude live 写入

修改：

1. `src-tauri/src/services/provider/live.rs`
2. `src-tauri/src/services/config.rs`

验证：

1. 切换 `claude` provider 写入 `~/.claude/settings.json`。
2. 切换 `claude-cn` provider 写入 `~/.claude-cn/settings.json`。
3. 两次切换互不覆盖。
4. 写入内容经过 `sanitize_claude_settings_for_live()`。

### Step 5：扩展 provider 服务 Claude-like 分支

修改：

1. `src-tauri/src/services/provider/mod.rs`
2. 必要时修改 `src-tauri/src/services/provider/live.rs` 的导入/读取逻辑

验证：

1. `claude-cn` 能新增 provider。
2. `claude-cn` 能编辑 provider。
3. `claude-cn` 能切换当前 provider。
4. `claude-cn` provider settings 必须是 JSON object。

### Step 6：前端新增应用入口和复用表单

修改：

1. `src/lib/api/types.ts`
2. `src/config/appConfig.tsx`
3. provider 表单路由相关组件

验证：

1. 主页面出现 `Claude CN` tab。
2. 进入 `Claude CN` tab 后可以新增 provider。
3. 表单字段与 Claude Code 一致。
4. 新增的 provider 只出现在 `Claude CN` 下。

### Step 7：设置页增加 Claude CN 配置目录

修改：

1. `src/components/settings/DirectorySettings.tsx`
2. `src/hooks/useSettings.ts`
3. `src/lib/api/settings.ts` 或相关 settings API 类型
4. i18n 文件

验证：

1. 设置页显示 `Claude CN 配置目录`。
2. 默认显示 resolved path `~/.claude-cn`。
3. 修改覆盖目录后，切换 provider 写入覆盖目录下的 `settings.json`。

### Step 8：补测试

优先新增/修改测试：

1. `src-tauri/tests/app_type_parse.rs`
2. `src-tauri/tests/provider_commands.rs`
3. `tests/hooks/useSettings.test.tsx`
4. 如已有 AppConfig 测试，则补 `claude-cn` 可见性断言。

验证命令：

```bash
pnpm test
cd src-tauri && cargo test
```

## 8. 工程规则

执行 agent 必须遵守：

1. 每个改动都应服务于 `claude-cn` 模型切换，不做无关重构。
2. 不复制 Claude 表单和服务实现，优先抽 helper 或扩展 match 分支。
3. 不改变现有 `claude` app id、路径和 provider 行为。
4. 不把 `claude-cn` 当成 `claude-desktop`，二者完全不同。
5. 所有硬编码 app list 的地方必须评估是否需要加入 `claude-cn`。
6. 所有读写当前 provider 的地方必须确保 `claude` 与 `claude-cn` 独立。
7. 新增字段使用 camelCase 序列化后应符合前端现有 settings 命名风格：
   - Rust: `claude_cn_config_dir`
   - JSON/TS: `claudeCnConfigDir`
8. 测试不能依赖真实用户的 `~/.claude` 或 `~/.claude-cn`；使用现有测试 home 覆盖机制。

## 9. 验收标准

### 9.1 功能验收

前置条件：

1. 已安装 fork 后的 cc-switch。
2. 本机存在可运行的 `claude` 和 `claude-cn`。
3. `claude-cn` 已确认读取 `~/.claude-cn/settings.json`。

操作：

1. 在 `Claude` tab 新建 Provider A：
   - `ANTHROPIC_BASE_URL = https://a.example.com`
   - `ANTHROPIC_AUTH_TOKEN = token-a`
   - `ANTHROPIC_DEFAULT_SONNET_MODEL = model-a`
2. 在 `Claude CN` tab 新建 Provider B：
   - `ANTHROPIC_BASE_URL = https://b.example.com`
   - `ANTHROPIC_AUTH_TOKEN = token-b`
   - `ANTHROPIC_DEFAULT_SONNET_MODEL = model-b`
3. 切换 `Claude` 到 Provider A。
4. 切换 `Claude CN` 到 Provider B。

预期：

1. `~/.claude/settings.json` 包含 Provider A。
2. `~/.claude-cn/settings.json` 包含 Provider B。
3. 两个文件中的 base URL、token、model 不交叉。

失败说明：

1. 如果两个文件被同一个 provider 覆盖，说明 live path 分发错误。
2. 如果 provider 出现在错误 tab，说明 app namespace 错误。

### 9.2 数据验收

检查 cc-switch 本地配置或数据库：

1. `claude` 和 `claude-cn` 有独立 provider 集合。
2. `current_provider_claude` 和 `current_provider_claude_cn` 分别保存。
3. 删除或修改 `claude-cn` provider 不影响 `claude` provider。

### 9.3 异常验收

场景 1：`~/.claude-cn` 不存在。

操作：

1. 删除或临时移动 `~/.claude-cn`。
2. 在 cc-switch 切换 `Claude CN` provider。

预期：

1. 自动创建目录。
2. 写入 `settings.json`。

场景 2：`claude-cn` 配置目录覆盖为不存在路径。

预期：

1. 自动创建目录。
2. 写入覆盖目录下的 `settings.json`。

场景 3：provider settings 不是 JSON object。

预期：

1. 保存或切换失败。
2. 错误提示说明 Claude 配置必须是 JSON 对象。

### 9.4 回归验收

必须确认：

1. 原 `Claude` provider 新增、编辑、切换仍正常。
2. `Codex`、`Gemini` provider 切换仍正常。
3. 设置页原有目录覆盖仍正常。
4. 应用重启后当前 provider 状态不丢失。

### 9.5 安全验收

检查：

1. 日志中不出现完整 token。
2. UI toast 或错误弹窗不显示完整 token。
3. `claude-cn` token 不写入 `~/.claude/settings.json`。
4. `claude` token 不写入 `~/.claude-cn/settings.json`。

## 10. 验证方案

### 10.1 自动化验证

执行：

```bash
pnpm test
cd src-tauri && cargo test
```

最低要求：

1. 所有既有测试通过。
2. 新增 AppType parse 测试通过。
3. 新增 settings path/current provider 测试通过。
4. 新增 provider switch 写入路径测试通过。

### 10.2 手工验证

准备：

```bash
mv ~/.claude/settings.json ~/.claude/settings.json.bak 2>/dev/null || true
mv ~/.claude-cn/settings.json ~/.claude-cn/settings.json.bak 2>/dev/null || true
```

操作：

1. 启动 cc-switch。
2. 在 `Claude` 和 `Claude CN` 分别创建不同 provider。
3. 分别切换。
4. 检查文件：

```bash
cat ~/.claude/settings.json
cat ~/.claude-cn/settings.json
```

预期：

1. `~/.claude/settings.json` 只包含原生 Claude provider。
2. `~/.claude-cn/settings.json` 只包含 Claude CN provider。

恢复：

```bash
mv ~/.claude/settings.json.bak ~/.claude/settings.json 2>/dev/null || true
mv ~/.claude-cn/settings.json.bak ~/.claude-cn/settings.json 2>/dev/null || true
```

## 11. 风险与回滚

### 11.1 风险：claude-cn CLI 不读取 `~/.claude-cn`

说明：

如果 `claude-cn` 只是复制了 `claude` 可执行文件，但内部仍读 `~/.claude`，则 cc-switch 写入 `~/.claude-cn/settings.json` 不会生效。

验证：

1. 手动写入 `~/.claude-cn/settings.json`。
2. 运行 `claude-cn`。
3. 确认请求使用 `~/.claude-cn` 中的 base URL/model。

处理：

1. 先修复 `claude-cn` CLI 的配置目录隔离。
2. 或者让 `claude-cn` 启动脚本设置它支持的配置目录环境变量。

### 11.2 风险：遗漏硬编码 app list

说明：

cc-switch 中多处存在硬编码 app list。遗漏会导致 UI 不显示、设置不保存、导入导出不完整或测试失败。

处理：

执行 agent 必须用以下搜索逐项检查：

```bash
rg -n "claude-desktop|claude|AppType::Claude|APP_IDS|SKILLS_APP_IDS|MCP_APP_IDS|current_provider_claude|claude_config_dir" src src-tauri
```

不是所有 `claude` 都要加 `claude-cn`，必须按语义判断。

### 11.3 风险：MCP/Skills/Prompt 编译牵连

说明：

`McpApps`、`SkillApps`、`McpRoot`、`PromptRoot` 对 AppType 有 match 分支。新增 `ClaudeCn` 后 Rust 会要求穷尽匹配。

处理：

第一阶段策略：

1. provider/settings 路径必须完整支持。
2. MCP/Skills/Prompt 如需补分支，先返回 false 或空配置，避免暴露半成品功能。
3. 后续再单独设计 `claude-cn` 的 MCP/Skills/Prompt 同步。

### 11.4 回滚方案

如果上线后发现问题：

1. 隐藏前端 `Claude CN` tab：从 `APP_IDS` 中移除 `"claude-cn"`。
2. 保留后端解析能力，避免已有配置无法加载。
3. 禁止切换 `claude-cn` provider，但不删除用户数据。
4. 用户可继续使用原 `cc-model` 切换 `~/.claude-cn/settings.json`。

代码回滚优先级：

1. UI 入口回滚最安全。
2. live 写入 helper 不必立刻删除。
3. AppType 解析和数据字段不建议删除，避免破坏已写入的配置。

## 12. Done When

本任务完成条件：

1. cc-switch 主界面出现 `Claude CN` 应用入口。
2. 可以在 `Claude CN` 下新增、编辑、切换 Claude-like provider。
3. 切换 `Claude CN` provider 后写入 `~/.claude-cn/settings.json`。
4. 切换原生 `Claude` provider 后仍写入 `~/.claude/settings.json`。
5. 两个 settings 文件内容互不覆盖。
6. 两个当前 provider 状态重启后互不覆盖。
7. 自动化测试通过：

```bash
pnpm test
cd src-tauri && cargo test
```

8. 手工验收确认 `claude-cn` CLI 实际读取 `~/.claude-cn/settings.json`。

