---
description: Start working on a task by ID, or mark a task as done
---

You are helping with task management for the LiveSvelte Gettext project.

## Command Variants

### Start working: `/task T001`
When the user provides just a task ID:
1. Read the task file from `docs/tasks/T001-*.md`
2. Display the task details (title, description, acceptance criteria)
3. Create a TodoWrite list with items from the acceptance criteria
4. Say: "Starting work on T001. I've created a todo list from the acceptance criteria. Let's begin!"
5. Begin working on the task

### Mark done: `/task T001 done`
When the user provides task ID + "done":
1. Read the task file from `docs/tasks/T001-*.md`
2. Update the Status field to "Done"
3. Update the Completed field to today's date (YYYY-MM-DD)
4. Write the updated file back
5. Ask: "Task T001 is complete! Should I move it to docs/archived/? (yes/no)"
6. Wait for user response:
   - If yes: Move file to `docs/archived/` and update `docs/INDEX.md`
   - If no: Leave in `docs/tasks/` and just update `docs/INDEX.md` status

## Task File Location

Tasks are stored in `docs/tasks/` with naming pattern: `T001-descriptive-name.md`

You may need to list the directory to find the exact filename for a given ID.

## Error Handling

- If task ID not found, list available tasks and ask user to clarify
- If task file format is unexpected, show the issue and ask how to proceed
- If user provides invalid command format, show examples of valid usage

## Context

This project uses an ID-based task management system where:
- Each task has a unique ID (T001, T002, etc.)
- Tasks live in `docs/tasks/` while active
- Completed tasks can be archived to `docs/archived/`
- `docs/INDEX.md` provides an overview of all tasks
