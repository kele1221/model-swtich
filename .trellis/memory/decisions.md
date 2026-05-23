# 关键决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-05-16 | 新增 `AppType::ClaudeCn` 而非把 Claude 配置改为 `~/.claude-cn` | 保持原有 claude 行为不变，两个槽位完全独立 |
| 2026-05-16 | claude-cn 复用 Claude provider 表单而非复制 | 避免维护两套表单，字段完全一致 |
| 2026-05-16 | MCP/Skills/Prompt 第一阶段最小兼容 (空/返回 false) | 缩小第一阶段范围，不做半成品功能 |
| 2026-05-16 | 配置文件路径使用 helper `get_claude_like_settings_path(app_type)` | 统一分发，避免硬编码路径 |
| 2026-05-16 | 新增字段 camelCase 序列化 (Rust: `claude_cn_config_dir`, JSON/TS: `claudeCnConfigDir`) | 符合前端现有 settings 命名风格 |
