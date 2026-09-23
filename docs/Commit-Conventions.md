# Commit Conventions

提交信息**一律英文**（与 `docs/Rules.md` 的 Naming 规则一致）；本文用中文解释。
本文件是提交风格的**唯一出处**，`docs/Rules.md` § Git 只留摘要 + 指路。

## 1. 主题行

```
<type>(<scope>): <祈使句、小写开头、不加句号>
```

- ≤ 72 字符；`type` 与 `scope` 小写；冒号后有且只有一个空格
- `type`：`feat` `fix` `refactor` `perf` `docs` `test` `chore` `build` `ci` `revert`
- 描述写**改了什么行为**，不写文件名、不写 `update xxx`、不写 `fix bug`
- 无合适 scope 时省略括号：`fix: keep the scan bar from covering the last row`

```
feat(settings): add a per-row icon color toggle
fix(settings): tint the theme row icons like the other leading icons
refactor(audio): drop just_audio dependency
perf(scan): skip unchanged files by mtime and size
docs(ui): record the leading icon color rule
chore(deps): bump package_info_plus to 8.3.0
```

**发布提交是例外**：`Release 0.2.6` —— 版本节点不是变更类型，不套前缀。

## 2. scope 词表

`player` `player-ui` `queue` `playlist` `library` `scan` `settings` `theme`
`lyrics` `hud` `menu` `macos` `deps` `docs` `test`

允许新增，但**优先复用**；拿不准就省略（`fix: ...`）而不是造一个近义词。

## 3. 正文（可省）

只写**为什么 / 取舍 / 被否掉的方案**：

- 不写改动清单（diff 里有）
- 不复述代码注释（注释在代码里）
- 能一行说清就不写正文

## 4. 结尾（保留）

```
Tests: <新增/改动的测试文件>（N 例）+ 为什么这么测
Full suite N passing; analyze clean.
```

- 没写测试就写 `no new tests; <为什么不必>`，别沉默略过
- `analyze` 还有历史遗留告警时**如实写清楚范围**，不要一律写 clean
- 这两行便宜且可验证，是唯一"建议保留的长内容"

## 5. 版本号

- 功能/修复提交里若动了 `pubspec.yaml`（版本或 build number），在正文末尾加一句
  说明「随本提交走，不另开 release 提交」，**不要拆成两个提交**
- 只改文档 / CI 的提交不动版本号

## 6. 粒度

- 一个提交一件事；顺手改到的无关文件另开提交
- 文档与 CHANGELOG 跟该功能**同一个提交**，不要"后面补"
- `dev` 分支 tracking `origin/dev`；用户没让 push 就不 push

## 7. 提示

提交前照 §1 的 `type(scope)` 自查主题行；若某个坑值得后人知道，写进
`docs/Pitfalls.md` 并在正文用一行 `Docs:` 指向它，而不是在正文里长篇复述。
