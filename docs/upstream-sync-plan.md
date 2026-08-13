# 上游同步方案（cc-switch v3.15.0 → v3.19.2）

> 状态：方案定稿，未执行。日期：2026-08-13
> 同步方式：**merge**（用户确认：哪种安全用哪种；merge 不改写历史、可 abort、无需 force-push，安全性最高）

## 1. 决策记录（用户已确认）

| # | 事项 | 决定 |
|---|---|---|
| 1 | `.trellis/` 工作区删除 | **保留不删**。恢复工作区删除的文件，`32e03e24` 提交原样保留 |
| 2 | 图标 | **保留自定义图标**（Model-Switch 品牌），二进制冲突时选自定义版本 |
| 3 | rebase / merge | **merge**。冲突只解决一轮（8 个自定义提交不重写、哈希不变），`git merge --abort` 可整体回退，推送无需 `--force`，最贴合"我的改动不受影响" |
| 4 | 数据备份 | **需要**。merge 前手动备份 `~/.cc-switch`（v3.17+ 首次启动会跑 schema v13→v16 迁移 + Codex 用量重建） |

> 注：merge 与 AGENTS.md 默认的 rebase 流程不同，按用户明确要求执行；后续同步上游仍走同样的 merge 流程，`my-custom` 历史稳定可追溯。

## 2. 现状盘点

| 项 | 值 |
|---|---|
| 本地 `main` | `4f0f103a`（上游 v3.15.0 时代） |
| 上游最新 | `1f38c838`（2026-08-12，tag `v3.19.2`） |
| 落后量 | **555 个提交**，178 个文件，+84,753 / -9,976 行 |
| `my-custom` | 8 个自定义提交（2026-05-17 ~ 05-23），131 个文件，+3,420 / -571 行 |
| 双方都改的文件 | **98 个**（冲突候选清单，见 §6 分组） |
| 工作区未提交 | 3 组：`.trellis/` 整目录删除（→ 恢复）、`icon.icns` 二进制更换（→ 保留）、`forwarder.rs` +68（400→429 限流规范化 + 5 个测试） |

### 自定义功能清单（全部保留）

| 提交 | 内容 |
|---|---|
| `4943ce41` | WIP 基线（受保护提交） |
| `f99d6cf8` | AGENTS.md 分支工作流说明 |
| `09170926` | rebrand 为 Model-Switch + Claude CN 代理路由 |
| `9a897250` | endpoint 保存失败显示真实错误 |
| `4403b9b1` | proxy takeover 时同步 claude-cn 实时 token 到 DB |
| `f1f24676` | Claude CN proxy takeover、前端 CN 表单、构建脚本加固、v3.15.1 |
| `b59a8fb5` | 剥离 fallback/haiku 1M 标记、构建后自动重启 |
| `32e03e24` | Trellis 工作流目录（保留） |

结论：上游代码中**没有任何** model-switch / Claude CN 相关功能（全仓 grep 仅 1 处无关命中），自定义功能无可丢弃项。

## 3. 上游主要变化（v3.16 → v3.19）

- proxy 子系统几乎重写：`forwarder.rs` +2,241、`handlers.rs` +2,663，新增 40+ 文件（`streaming_codex_*`、`transform_*`、`media_sanitizer`、`tool_media`、`xai_oauth_auth` 等）
- 新功能：Grok Build 支持、xAI OAuth、DeepSeek/Volcengine Coding Plan 预设、Claude Desktop 官方预设与指南、Copilot takeover、模型定价系统、WebDAV/S3 同步重构、后端驱动的 updater 重启
- DB schema 迁移 v13 → v16，含一次性 Codex 用量自动重建（启动时自动备份）
- 版本/元数据：`package.json` 3.19.2；`tauri.conf.json` productName 仍为 "CC Switch"、identifier `com.ccswitch.desktop`（自定义分支为 "Model-Switch" / `com.modelswitch.desktop`）

## 4. 风险预判

1. **proxy 重灾区**：自定义改动集中在 `src-tauri/src/proxy/*`、`services/proxy.rs`、`services/provider/*`，与上游重写区完全重叠，需逐文件按新架构移植
2. **二进制图标**：`icons/*` 冲突只能手工选边，统一选自定义图标
3. **DB 迁移**：v3.17+ 首次启动跑 schema v13→v16 + Codex 用量重建，有自动备份但需手动备份双保险
4. **Claude Desktop 官方预设**（上游新增）与自定义 CN 表单交互，合并时确认行为不打架
5. 版本号冲突：合并时取上游 `3.19.2`，保留自定义 productName/identifier
6. merge 的缺点：历史出现 merge commit（可接受）；若后续想改回 rebase，可用 backup 分支做参考

## 5. 执行步骤

### 阶段 0：备份（必须先做）

```bash
# git 备份
git branch my-custom-backup-20260813
git rev-parse my-custom > /tmp/my-custom-head.txt

# 数据目录备份（macOS）
ls -la ~/.cc-switch
ditto ~/.cc-switch ~/.cc-switch-backup-20260813
# 验证
diff -rq ~/.cc-switch ~/.cc-switch-backup-20260813 | head
```

### 阶段 1：收拢未提交改动（在 my-custom 上）

```bash
git restore .trellis                      # 恢复误删，保留 trellis 目录
git add src-tauri/src/proxy/forwarder.rs
git commit -m "fix: normalize upstream 400 rate-limit to 429"
git add src-tauri/icons/icon.icns
git commit -m "chore: update app icon"
```

目标：工作区干净、改动全部入提交，merge 前无悬挂状态。

### 阶段 2：更新 main

```bash
git switch main
git merge --ff-only upstream/main
git push origin main
```

### 阶段 3：merge（核心步骤）

```bash
git switch my-custom
git merge main          # 冲突一次性解决；随时可 git merge --abort 整体回退
```

冲突处理分组原则：

| 分组 | 文件 | 策略 |
|---|---|---|
| 纯自定义新增 | `AGENTS.md`、`CLAUDE.md`、`PROJECT_INIT_RECORD.md`、`build-arm64-dmg.sh`、`hot-start.sh`、`.trellis/` | 无冲突，保留 |
| 元数据/版本 | `package.json`、`Cargo.toml`、`Cargo.lock`、`tauri.conf.json` | 上游版本 + 自定义 productName/identifier |
| 图标 | `src-tauri/icons/*` | 二进制：保留自定义图标 |
| 后端 Rust（proxy 重灾区） | `proxy/forwarder.rs`、`handlers.rs`、`server.rs`、`types.rs`、`services/proxy.rs`、`services/provider/*`、`claude_desktop_config.rs`、`settings.rs`、`tray.rs` 等 | 以上游新结构为骨架，把 Claude CN 路由/token 同步/400→429 移植进去，逐文件手动合并 |
| 前端 | `ProxyPanel.tsx`、`ClaudeDesktopRouteToggle.tsx`、provider 表单系列、`zh.json` 等 | 以上游新 UI 为骨架，重放 CN 表单支持 |
| 测试 | `src-tauri/tests/*`、`tests/*` | 按新 API 适配 |

冲突不明确的文件**停下来问用户**，不自行猜测行为。

### 阶段 4：验证

```bash
cd src-tauri && cargo test --lib proxy && cargo test   # 后端单测
cd .. && npm test                                      # 前端 vitest
npm run build && (cd src-tauri && cargo build)         # 双端构建
```

冒烟项：Claude CN 代理切换、图标/About 页品牌、400→429 限流、DB 迁移后数据完整。

### 阶段 5：推送

```bash
git push origin my-custom        # 普通推送即可，无需 force
# main 已在阶段 2 推送
```

## 6. 备选方案

- **rebase**（不采用）：历史线性，但 8 个提交重写、冲突可能逐提交重复出现、需 `--force-with-lease`，风险高于 merge
- **cherry-pick 到新分支**：若 merge 后冲突过碎，可基于新 main 建 `my-custom-v2` 逐个 pick，但会丢失提交原哈希，仅作兜底
- 后续上游再更新：重复阶段 2（main ff）+ merge 即可

## 7. 工作量预估

- 冲突解决 + 新架构适配：约 0.5~1 个工作日
- 大头在 proxy 后端移植（forwarder/handlers/services）与前端表单重放
- 建议执行时开新任务分多轮做，每轮解决一组文件并编译验证
