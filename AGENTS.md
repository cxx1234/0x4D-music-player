# AGENTS.md

本仓库的约定全部写在 `docs/` 下。动手前按需读，别凭"最近的提交长什么样"猜。

| 文件 | 什么时候读 |
| --- | --- |
| `docs/Rules.md` | 通用开发规则（结构、命名、分层、错误处理）——改任何代码前 |
| `docs/Commit-Conventions.md` | 提交前：`type(scope): 描述`、scope 词表、正文与结尾格式 |
| `docs/Pitfalls.md` | 遇到构建 / 平台 / 框架层怪问题**之前**先搜一遍，别重复踩 |
| `docs/UI-Rules.md` | 改界面：布局、行高、当前播放高亮、HUD、菜单入口等约束 |
| `docs/Architecture.md` | 分层与模块边界 |
| `docs/Performance-Optimization.md` | 性能约束与已知热点 |
| `docs/ErrorHandling.md` | 错误处理约定 |
| `docs/TODO.md` | 未做的路线图 —— **不要顺手实现** |

## 工作约定

- 提交信息用 `type(scope): ...`，按 `docs/Commit-Conventions.md`，不要自创风格
- 改完跑 `flutter analyze` 与 `flutter test`，结果写进提交结尾（有历史遗留告警要如实写）
- 文档与 CHANGELOG 跟功能**同一个提交**
- 版本号与功能提交同走，不拆 release 提交（见 `docs/Commit-Conventions.md` §5）
- `dev` 分支 tracking `origin/dev`；**用户没让 push 就不要 push**
- 不确定就问，不要猜（`docs/Rules.md` § AI Collaboration）
