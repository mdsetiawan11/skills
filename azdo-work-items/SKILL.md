---
name: azdo-work-items
description: >
  Create and update Azure DevOps work items through the Sprintly backend. Use when Codex is asked to make
  Azure DevOps work items, backlog items, tasks, bugs, user stories, PBIs, child items, comments, or links.
  Also triggers when the user mentions "buat story", "tulis backlog", "pecah task", "buat feature ADO",
  "acceptance criteria", "given when then", or asks for sprint planning templates. This skill covers
  work item writing rules, title formats, description templates, acceptance criteria (Given/When/Then),
  and required field checklists — then creates or updates items via the Sprintly BE/API.
---

# Azure DevOps Work Items

Use the Sprintly backend as the only integration point. Do not call Azure DevOps REST APIs directly
unless the user explicitly asks to bypass Sprintly.

---

## Work Item Hierarchy

```
Epic
 └── Feature
      └── User Story (Agile) / Product Backlog Item (Scrum)
           └── Task
```

**User Story = Product Backlog Item** — only the name differs by process template.

- Agile process → **User Story**
- Scrum process → **Product Backlog Item (PBI)**

Check at: **Project Settings → Overview → Process**

---

## Writing Rules by Work Item Type

### Feature

Large functionality that may span several sprints.

**Title format:** Clear noun phrase describing the capability.

```
✅ User Management
✅ Audit Findings Report
❌ Fix user stuff
❌ Backend API
```

**Template:**

```markdown
## Description

[What is being built and why — 2-3 sentences]

## Acceptance Criteria

- [ ] Criterion 1 (measurable)
- [ ] Criterion 2 (measurable)

## Out of Scope

- [What is explicitly NOT included in this feature]
```

### User Story / Product Backlog Item

Requirements from the user's perspective. Must be completable within **1 sprint**.

**Title format:** `[Role] can [do something]`

```
✅ Admin can add new users
✅ Auditor can export report to PDF
❌ Add POST /users endpoint
❌ Create user page
```

**Template:**

```markdown
## User Story

As a [role/persona],
I want [feature/capability],
So that [business benefit/goal].

## Acceptance Criteria

Given [initial condition]
When [action performed]
Then [expected result]

Given [edge case / error condition]
When [action]
Then [result]

## Notes / Assumptions

- [Technical notes or business assumptions]
- [Available roles, constraints, dependencies]
```

**Required fields:** Title, Description, Acceptance Criteria, **Story Points**

### Task

Technical unit of work. Must be completable in **≤ 1 day**.

**Title format:** `[Verb] + [Specific object]`

```
✅ Create POST /api/users endpoint in ASP.NET Core
✅ Implement UserForm component in Vue 3
✅ Write unit tests for UserService.CreateAsync
✅ Update Swagger docs for /api/users endpoint
❌ Backend
❌ Fix bug
❌ Testing
```

**Template:**

```markdown
## What is being done

[Technical details: libraries, methods, files changed]

## Definition of Done

- [ ] Code complete and reviewed
- [ ] Unit tests written (if applicable)
- [ ] No breaking changes
- [ ] Documentation/Swagger updated if API changes
```

**Required fields:** Title, Description, **Original Estimate (hours)**

---

## Required Fields per Work Item Type

| Field               | Feature | User Story | Task |
| ------------------- | :-----: | :--------: | :--: |
| Title               |   ✅    |     ✅     |  ✅  |
| Description         |   ✅    |     ✅     |  ✅  |
| Acceptance Criteria |   ✅    |     ✅     |  —   |
| Story Points        |    —    |     ✅     |  —   |
| Original Estimate   |    —    |     —      |  ✅  |
| Area Path           |   ✅    |     ✅     |  ✅  |
| Iteration Path      |   ✅    |     ✅     |  ✅  |
| Priority            |   ✅    |     ✅     |  ✅  |
| Tags                |   rec   |    rec     | rec  |

---

## Anti-Patterns to Avoid

| ❌ Avoid                            | ✅ Do Instead                                   |
| ----------------------------------- | ----------------------------------------------- |
| Story too large (> 1 sprint)        | Split into multiple smaller stories             |
| Ambiguous AC: "system must be fast" | Measurable AC: "response time < 2 seconds"      |
| Task without estimate               | Always fill Original Estimate (hours)           |
| Technical tasks at Story level      | Keep tasks at Task level                        |
| Generic title: "Fix bug"            | Specific: "Fix null ref in UserService.GetById" |
| Story Points left empty             | Must be set before Sprint Planning              |

---

## Recommended Tags

`backend` · `frontend` · `database` · `api` · `ui` · `hotfix` · `tech-debt` · `testing` · `refactor`

---

## Workflow

Before creating or updating a work item, first apply the writing rules above to draft
the title, description, and acceptance criteria in the correct format for the work item type.
Then proceed with the Sprintly workflow:

1. Confirm the backend base URL. Default to `http://localhost:8181`. If the backend is not running, start it from `D:\Repository\FRONTEND\Sprintly\backend` with `dotnet run`.
2. Check backend health with `GET /api/health`.
3. Resolve the target project with `GET /api/projects`; accept either project id or project name.
4. Retrieve project iterations with `GET /api/projects/{projectId}/iterations`. Identify the current
   active sprint (check `?timeframe=current`, compare current date to start/end dates, or find the
   active flag) and use its exact `path` as `iterationPath`.
5. If an assignee is requested, load members with `GET /api/projects/{projectId}/members` and prefer
   `uniqueName` for `assignedTo`.
6. Draft the work item details (title, type, description, acceptance criteria, assignee, iteration,
   story points, original estimate) applying the writing rules above. Present them clearly to the user.
   Always append `[Generated by AI]` at the end of the description.
7. Request explicit user confirmation before any create or update action. Do not make POST/PATCH calls
   or run helper scripts until the user approves.
8. Create with `POST /api/projects/{projectId}/workitems` or update with
   `PATCH /api/projects/{projectId}/workitems/{id}`.
9. Report the created/updated work item: `id`, `title`, `type`, `state`, `assignedTo`, `iterationPath`.

If required inputs are missing, make a conservative assumption only when the repo context clearly
provides it. Otherwise ask one concise question before presenting the draft.

## From Git History

When the user asks to create work items from Git history, commits, branches, or a commit range,
do not derive items from commit titles alone. Inspect the actual changes before drafting each
work item:

1. Identify the relevant commits with `git log` or the user-provided range.
2. Read each commit's diff with `git show --stat --patch <commit>` or an equivalent command. For
   ranges, inspect the combined and/or per-commit diff as needed.
3. Use the changed files, code paths, behavior changes, tests, migrations, and config updates from
   the diff to write the work item description following the writing rules above. Append
   `[Generated by AI]`.
4. Apply the correct title format for the work item type.
5. If a commit title and diff disagree, trust the diff and mention any ambiguity before asking for
   confirmation.

## Create Request Shape

Send JSON:

```json
{
  "title": "Required title — follow format for the work item type",
  "type": "User Story",
  "description": "HTML or plain text following the type's template. End with [Generated by AI].",
  "assignedTo": "optional.user@example.com",
  "parentId": 12345,
  "iterationPath": "Project\\Sprint 1"
}
```

Use Azure DevOps types exactly as the target project expects: `Epic`, `Feature`, `Product Backlog Item`,
`User Story`, `Bug`, or `Task`.

## Helper Script

Prefer the bundled PowerShell helper for creating a single item:

```powershell
.agents\skills\azdo-work-items\scripts\create_work_item.ps1 `
  -ProjectId "MyProject" `
  -Title "Admin can add new users" `
  -Type "Task" `
  -Description "Create an admin form to add new users with role assignment." `
  -ParentId 12345 `
  -IterationPath "MyProject\\Sprint 1"
```

The script checks `/api/health`, posts to Sprintly, and prints the created item JSON.

For batch creation, loop over structured input and call the same backend endpoint. Keep parent-child
order explicit: create the parent first, then create children using the returned parent `id`.

## References

Read `references/sprintly-api.md` when you need endpoint details, request fields, response fields,
update/comment/link examples, or troubleshooting notes.
