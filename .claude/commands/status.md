---
description: Show project overview and current status
---

You are providing a project status overview for the LiveSvelte Gettext project.

## What to do

1. Read `docs/INDEX.md` (the central tracking document)
2. Display the contents in a clear, formatted way
3. Add any helpful context, such as:
   - Highlighting tasks that are currently in progress
   - Noting any blocked tasks
   - Suggesting next steps if unclear
   - Showing recent momentum (if you can see git history)

## Additional Context to Provide

After showing the INDEX, you might also:
- Check git status to see uncommitted work
- Look at recent commits to show progress
- Identify any quick wins or urgent items
- Suggest using `/task T001` to start working

## If INDEX.md doesn't exist

If the file isn't found:
1. Explain that INDEX.md is the central tracking document
2. Offer to create it by scanning docs/tasks/ and docs/plans/
3. Generate an initial version based on existing files

## Example Output Format

```
LiveSvelte Gettext - Project Status
=====================================

📊 Overview
- Active tasks: 5
- In progress: 1
- Completed: 2
- Active plans: 1

🎯 Current Focus
[In Progress] T001: Implement Extractor Regex (Phase 1)

📋 Up Next
- T002: Build Macro System
- T003: TypeScript Client

🎉 Recently Completed
- T000: Project Setup
- T000: Documentation Structure

---

Use /task T001 to continue current work, or /tasks to see all active tasks.
```
