# LiveSvelte Gettext - Claude Collaboration Guide

## Project Overview

**What we're building:** A zero-maintenance i18n library for Phoenix + Svelte applications that uses compile-time extraction and Elixir macros to automatically extract translation strings from Svelte components.

**Key Innovation:** No generated files to commit. Everything happens at compile time using `@external_resource` and macro-generated AST.

**Tech Stack:**
- Elixir library (will publish to Hex.pm)
- TypeScript client (runtime translations in Svelte)
- Igniter installer (one-command setup)

**Architecture:** See `docs/plans/P001-overall-project-plan.md` for complete technical details.

---

## Project Structure

```
docs/
├── archived/       # Completed plans and tasks (for reference)
├── plans/          # Strategic documents (P001, P002...)
├── tasks/          # Active work items (T001, T002...)
└── INDEX.md        # Quick overview of all active work
```

**Naming Convention:**
- Plans: `P001-descriptive-name.md` (strategic, multi-week initiatives)
- Tasks: `T001-descriptive-name.md` (concrete, implementable work)

---

## Task Management Workflow

### Starting Work
1. Use `/tasks` to see all active tasks
2. Use `/task T001` to start working on a specific task
   - This loads context and creates a TodoWrite list for the session
3. Work through the task, updating status as you go

### Completing Work
1. Use `/task T001 done` to mark complete
2. I will ask: "Task T001 is complete! Should I move it to docs/archived/?"
3. If yes: Move to `docs/archived/T001-name.md` and update INDEX.md
4. If no: Leave in `docs/tasks/` (useful for tasks needing minor tweaks)

### Creating New Tasks
- Create manually in `docs/tasks/` using the task template below
- Use sequential IDs (T001, T002, T003...)
- Update `docs/INDEX.md` when adding new tasks

---

## Task File Template

```markdown
# T00X: Task Title

**Status:** Not Started | In Progress | Done
**Phase:** [1-5] - Phase Name
**Assignee:** @username (or leave empty)
**Created:** YYYY-MM-DD
**Completed:** (empty until done)

## Description
Clear description of what needs to be done.

## Acceptance Criteria
- [ ] Specific, testable requirement
- [ ] Another requirement
- [ ] Final requirement

## Implementation Notes
(Add notes as you work - decisions made, gotchas discovered, etc.)

## Related
- Blocks: T00X (if this blocks other tasks)
- Blocked by: T00X (if waiting on other tasks)
- Part of: P001 (which plan this belongs to)
```

---

## Development Guidelines

### Code Quality Standards

**Elixir:**
- Follow Elixir formatter rules (`.formatter.exs`)
- Always add `@moduledoc` and `@doc` for public functions
- Use `@spec` type specifications for public APIs
- Follow naming conventions from `docs/plans/P001`

**TypeScript:**
- Use strict TypeScript mode
- Export types for all public functions
- Include JSDoc comments with examples

### Testing Approach

**Test-Driven Development (TDD) for:**
- `LiveSvelteGettext.Extractor` module (complex regex, many edge cases)
- `LiveSvelteGettext.Compiler` module (AST generation is tricky)
- TypeScript `gettext()` and `ngettext()` functions

**Standard testing for:**
- Igniter installer (integration tests)
- Configuration validation
- Documentation examples

**Test Organization:**
- Unit tests in `test/livesvelte_gettext/`
- Fixtures in `test/fixtures/`
- Integration tests in `test/integration/`

### When to Ask vs. Proceed

**Always ask before:**
- Changing public API design
- Making architectural decisions not in the plan
- Adding new dependencies
- Significant refactoring of working code

**Proceed independently:**
- Implementation details within a task
- Test organization and fixture creation
- Refactoring internal/private functions
- Documentation improvements
- Bug fixes with clear solutions

---

## Session Management

### Within a Session
- Use **TodoWrite** for real-time task tracking
- Update task file status as you progress
- Add implementation notes to task files

### Between Sessions
- All progress is saved in task files (`docs/tasks/`)
- `docs/INDEX.md` provides quick overview of project state
- Task files contain all context needed to resume work

---

## Documentation Maintenance

**Keep updated:**
- `docs/INDEX.md` - When tasks change status or new ones are created
- `CHANGELOG.md` - When completing user-facing features
- Task files - Add implementation notes and decisions made
- `README.md` - When completing major phases

**Don't update unnecessarily:**
- Project plan (`P001`) - Only for major architectural changes
- Archived tasks - They're historical records

---

## Quality Gates

**Before marking a task done:**
- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] Code formatted (`mix format`)
- [ ] Documentation added for public APIs
- [ ] Implementation notes added to task file

**Before commits:**
- [ ] `mix format` run
- [ ] `mix test` passing
- [ ] No compiler warnings

---

## Slash Commands

Use these for efficient workflow:

- `/task T001` - Start working on task T001
- `/task T001 done` - Mark task complete (prompts for archiving)
- `/tasks` - List all active tasks with status
- `/plan P001` - Open and discuss a plan
- `/status` - Show project overview from INDEX.md

---

## Communication Style

- Be concise and technical
- Reference specific files with paths (e.g., `lib/livesvelte_gettext/extractor.ex:45`)
- Use TodoWrite to show progress during sessions
- Ask clarifying questions when requirements are ambiguous
- Suggest improvements when you spot opportunities

---

## Resources

- **Project Plan:** `docs/plans/P001-overall-project-plan.md`
- **Active Tasks:** `docs/INDEX.md`
- **Elixir Docs:** https://elixir-lang.org/docs.html
- **Gettext Docs:** https://hexdocs.pm/gettext
- **Igniter Docs:** https://hexdocs.pm/igniter
