---
description: List all active tasks with their current status
---

You are helping with task management for the LiveSvelte Gettext project.

## What to do

1. List all files in `docs/tasks/` directory
2. Read each task file to get:
   - Task ID (from filename)
   - Task title (from first heading)
   - Status (from Status field)
   - Phase (from Phase field)
   - Assignee (if present)
3. Display a formatted list like:

```
Active Tasks:

Phase 1: Core Extraction Engine
  [In Progress] T001: Implement Extractor Regex - @nille
  [Not Started] T006: Write Extractor Tests

Phase 2: Compile-Time Macro System
  [Not Started] T002: Build __using__ Macro
  [Not Started] T007: Test Macro Generation

Phase 3: TypeScript Client Library
  [Not Started] T003: Create TypeScript Client

Phase 4: Igniter Installer
  [Not Started] T004: Build Igniter Task

Phase 5: Documentation & Publishing
  [Not Started] T005: Write Documentation

Total: 7 active tasks (1 in progress, 6 not started)
```

## Helpful Context

After listing tasks, you might ask:
- "Which task would you like to work on? Use `/task T001` to start."
- Or if there's an obvious next step: "Should we continue with T001?"

## Error Handling

- If no tasks exist, suggest creating the first task
- If `docs/tasks/` doesn't exist, explain the directory structure
