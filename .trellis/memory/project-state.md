# 项目状态

## 仓库信息

- Fork source: `farion1231/cc-switch`
- Origin: `kele1221/model-swtich`
- Local path: `/Users/k/code/exploratory-code/model-swtich`
- 默认工作分支: `my-custom`
- Baseline commit: `4943ce41 WIP: preserve custom changes`

## 已实现功能

claude-cn 模型切换 (commit `b59a8fb5`):

- AppType::ClaudeCn 枚举 (含 serde alias: `claude-cn`, `claude_cn`, `claudeCn`)
- 独立配置目录 `~/.claude-cn/settings.json` (支持用户覆盖)
- 独立 current_provider_claude_cn 状态
- Claude-like live 写入复用 (`get_claude_like_settings_path`)
- 数据库 schema migration v10→v11 (`enabled_claude_cn` 列)
- 前端: app tab、provider 表单复用、目录设置、i18n (zh/en/ja)
- AppId 类型联合扩展

## 未解决问题

- final-verify 报告 `DONE_WITH_CONCERNS` — workflow metadata 未 reconcile
- `verify_delegate_workflow.py` 因 artifact metadata 不一致而失败

## 测试状态

- 前端测试: 234 tests, 40 文件 — 通过
- Rust 测试: 1259 tests, 13 二进制 — 通过
