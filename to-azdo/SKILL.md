---
name: to-azdo
description: Convert PRDs, specs, user stories, and implementation decisions into Azure DevOps work items through the Sprintly backend. Use when Codex needs to create Feature, User Story, Product Backlog Item, or Task work items from a PRD, especially after using $to-prd.
---

# PRD to Azure DevOps

Convert a PRD into Azure DevOps work items by using the Sprintly backend in this repo. Do not call Azure DevOps REST APIs directly.

## Workflow

1. Read the PRD or current PRD draft. If mapping details are needed, read `references/prd-to-work-items.md`.
2. Confirm the Sprintly backend base URL. Default to `http://localhost:8181`.
3. Resolve the Azure DevOps project:
   - Use a project id or name from the user prompt, PRD, repo context, or prior conversation when available.
   - If no target project is available, ask one concise question before creating live Azure DevOps data.
   - Use `GET /api/projects` to confirm the target.
4. Resolve placement:
   - Always retrieve the project's iterations using `GET /api/projects/{projectId}/iterations`. Identify the current active sprint (by checking for timeframe indicators like `?timeframe=current`, comparing the current date to the start/end dates if available, or finding the active flag/metadata in the returned iterations) and always use its exact `path` as `iterationPath`.
   - Use `GET /api/projects/{projectId}/members` and prefer `uniqueName` as `assignedTo` only when requested.
5. Build the work item hierarchy:
   - Create one parent `Feature` for the PRD.
   - Create child `User Story` items from PRD user stories by default.
   - Use `Product Backlog Item` instead of `User Story` only when the target project/process clearly uses Scrum terminology or the user requests it.
   - Create `Task` children only for concrete implementation or testing decisions.
6. Create the parent first, then create children with the returned parent `id`.
7. Report created `id`, `title`, `type`, `state`, `assignedTo`, and `iterationPath`.

## Batch Script

Prefer the bundled script for PRD-to-work-item creation:

```powershell
.agents\skills\to-azdo\scripts\create_prd_work_items.ps1 `
  -ProjectId "MyProject" `
  -PrdPath ".\feature.prd.md" `
  -StoryType "User Story"
```

Optional parameters:

```powershell
-BaseUrl "http://localhost:8181"
-AssignedTo "dev@example.com"
-IterationPath "Project\\Sprint 1"
-StoryType "Product Backlog Item"
```

The script accepts Markdown PRDs that follow the `$to-prd` template and structured JSON with these top-level fields: `title`, `problemStatement`, `solution`, `userStories`, `implementationDecisions`, `testingDecisions`, `outOfScope`, and `furtherNotes`.

## Safety Rules

- Never create live work items without a resolved project.
- Do not infer assignees unless the user asks for them or they are explicit in the PRD/prompt. Always resolve and use the current active sprint for the iteration path.
- Keep vague notes, out-of-scope items, and broad architectural context in descriptions or comments; do not create standalone work items from them.
- Use the existing `$azdo-work-items` skill for endpoint details, troubleshooting, updates, comments, or manual single-item operations.
