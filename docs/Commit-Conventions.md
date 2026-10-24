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
- **build number 怎么加**：要动版本号、但没有新增功能（`fix` `refactor` `perf`
  `chore` `test` `build` `ci` `revert`）时，只把 `+x` 加一（`0.2.6+2` → `0.2.6+3`）；
  有新增功能（`feat`）时 `x.y.z` 与 `+x` 都按用户指定的版本来，不自作主张

## 6. 粒度

- 一个提交一件事；顺手改到的无关文件另开提交
- 文档与 CHANGELOG 跟该功能**同一个提交**，不要"后面补"
- `dev` 分支 tracking `origin/dev`；用户没让 push 就不 push

## 7. 提示

提交前照 §1 的 `type(scope)` 自查主题行；若某个坑值得后人知道，写进
`docs/Pitfalls.md` 并在正文用一行 `Docs:` 指向它，而不是在正文里长篇复述。

## 8. Issue / PR

**语言分工**：`docs/` 与代码注释用中文，commit / CHANGELOG / **issue / PR 一律英文** ——
它们属于同一条历史链（issue → commit → CHANGELOG），换语言会让引用关系断开，也让
public 仓库的 issue 搜不到、引用不了。引用中文 UI 原文时保留原样（如 `我的收藏`）。

- **关得回去**：修复类提交在正文末尾写 `Closes #<n>`（修多个就多行）。关闭评论写三件事：
  根因一句 / 落点（sha 或文件）/ 怎么验证。只写 `Fixed in <sha>` 不够 —— 那个 sha 的主题行
  往往和 issue 无关（#4 就是反例：修复藏在 `cbc19f9` 的 "Bug fixes" 第 2 条里）。
- **正文不是可选**：现象 / 复现 / 期望 vs 实际 / 环境。环境记录**当时实测**的版本，
  之后机器升级了也不要改 —— 那条版本是"能复现的那个"。空正文的 issue 事后无法判断是否复发。
- **勾选必须与代码一致**：勾之前先找出落点（文件或 sha）；找不到就说明它没做完。
  同理，写的计划范围也要和实际交付对齐（#3 的 "USLT/SYLT" 只交付了 USLT）。
- **一条 issue 一件事**：跟踪型 cockpit issue 只放清单和链接，具体工作拆成独立 issue；
  拆出去的子项在原 issue 里标 `moved to #<n>` 并取消勾选，别留悬空的 `[ ]`。
- **label**：至少一个 `bug` / `enhancement` / `feature`；`V0.x` 里程碑只挂落在该版本范围内的 issue，
  版本发布后及时关掉对应里程碑。
- 模板在 `.github/ISSUE_TEMPLATE/`（bug / feature 两个表单），新建 issue 时按表单填。
