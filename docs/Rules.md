# Development Rules

These rules apply to both human contributors and AI assistants.

⸻

## General

* Keep the project simple.
* Prefer readability over clever code.
* Keep functions focused on a single responsibility.
* Avoid unnecessary abstractions.

⸻

## Naming

* Use English only.
* Use meaningful names.
* Avoid abbreviations.
* Class names use PascalCase.
* Variables and methods use camelCase.

⸻

## Project Structure

* New features belong under features/.
* Shared code belongs under core/.
* Reusable UI belongs under widgets/.
* Models belong under models/.

Do not place unrelated files together.

⸻

## UI

* Keep Widgets lightweight.
* Avoid business logic inside Widgets.
* Prefer StatelessWidget whenever possible.
* Move complex logic into ViewModels.

⸻

## State Management

* One ViewModel per feature.
* Avoid global mutable state.
* Keep state predictable.

⸻

## Data Layer

* UI must never query SQLite directly.
* UI must never read files directly.
* Repositories are responsible for data access.

⸻

## Audio

* Never call playback libraries directly from Widgets.
* Always use PlaybackService.
* AudioEngine should remain replaceable.

⸻

## Error Handling

* Handle expected errors gracefully.
* Do not silently ignore exceptions.
* Provide meaningful log messages.

⸻

## Code Style

* Prefer async/await.
* Avoid deeply nested code.
* Keep files reasonably small.
* Remove dead code.
* Remove commented-out code before merging.

⸻

## Dependencies

Before adding a package:

* Check maintenance status.
* Check license.
* Check platform support.

Avoid adding dependencies for trivial functionality.

⸻

## Git

One feature per commit.

Write clear commit messages.

Examples:

feat(player): implement playback queue

fix(scanner): ignore hidden folders

refactor(audio): introduce AudioEngine abstraction

⸻

## Pull Requests

Every Pull Request should:

* Solve one problem.
* Keep changes focused.
* Avoid unrelated refactoring.
* Update documentation if architecture changes.

⸻

## AI Collaboration

Before generating code, AI assistants should:

1. Read Architecture.md
2. Follow these Development Rules
3. Stay within the current GitHub Issue
4. Avoid implementing future roadmap items

When uncertain, prefer asking for clarification instead of making assumptions.

⸻

## Final Principle

Code is written once but maintained for years.

Every change should make the project easier to understand, not harder.