# Trellis 工作流模式

## 概述

Trellis 是一个轻量级的 AI 辅助开发工作流框架，包含三个核心目录：

```
.trellis/
  specs/    — 需求规格和技术方案
  tasks/    — 任务定义和进度跟踪
  memory/   — 项目记忆、决策记录、上下文
```

## 工作流阶段

### 1. 需求阶段
- 编写/更新 spec 到 `.trellis/specs/`
- 明确验收标准

### 2. 任务分解
- 创建 task 到 `.trellis/tasks/`
- 每个 task 有明确 scope、依赖、验收条件

### 3. 实现 → Review → Rework 循环
```
task: implement
  → review: spec
  → review: quality
  → (if concerns) rework
  → (if concerns) re-review
  → final-verify
  → accept
```

### 4. 归档
- 更新 `.trellis/memory/` 记录关键决策和经验

## 与 codex_with_cc 的关系

Trellis 是**人机协作层**，定义 **what/why**；
`codex_with_cc` 是**执行层**，通过 Claude Code delegate 实现 **how**。

- Trellis specs → codex_with_cc workflow prompt
- Trellis tasks → codex_with_cc task definitions
- codex_with_cc runs/reports → Trellis memory updates
