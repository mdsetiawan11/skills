# PRD to Azure DevOps Work Item Mapping

Use these rules when converting a PRD into Sprintly-backed Azure DevOps work items.

## Source Sections

Expect the PRD to follow the `$to-prd` template:

- `Problem Statement`
- `Solution`
- `User Stories`
- `Implementation Decisions`
- `Testing Decisions`
- `Out of Scope`
- `Further Notes`

Structured JSON may use equivalent camelCase fields: `problemStatement`, `userStories`, `implementationDecisions`, `testingDecisions`, `outOfScope`, and `furtherNotes`.

## Hierarchy

Create work items in this order:

1. `Feature`: one parent that represents the full PRD.
2. `User Story` or `Product Backlog Item`: one child for each PRD user story.
3. `Task`: children for concrete implementation and testing decisions.

Use `User Story` by default. Use `Product Backlog Item` only when the target project/process clearly uses Scrum terminology or the user requests it.

## Field Mapping

Feature:

- Title: concise PRD feature name.
- Description: combine problem statement, solution, out of scope, and further notes.

Story/backlog item:

- Title: normalize from the PRD user story. Prefer the `I want ...` clause when present.
- Description: include the original user story and any relevant acceptance or testing context that can be inferred from the PRD.
- Parent: the created Feature id.

Task:

- Title: imperative summary of the concrete engineering or testing work.
- Description: include the original implementation/testing decision.
- Parent: the most relevant story when obvious; otherwise the Feature.

## Filtering

Create tasks only from actionable decisions. Good task inputs mention concrete work such as build, add, update, implement, integrate, validate, test, migrate, expose, persist, remove, or refactor.

Do not create separate work items for:

- Out-of-scope items.
- Further notes.
- Vague architecture observations.
- Broad context with no clear action.

Keep those details in descriptions or comments instead.

## Runtime Defaults

- Base URL: `http://localhost:8181`.
- Story type: `User Story`.
- AssignedTo: omit unless explicit.
- IterationPath: omit unless explicit, and always use the exact iteration `path` from Sprintly.
