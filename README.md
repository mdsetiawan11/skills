# Codex Integration Skills for Azure DevOps & Sprintly

This repository contains a set of custom Codex skills and helper tools designed to streamline the lifecycle of software requirements and project management. Specifically, it enables automatic conversion of conversation context into Product Requirement Documents (PRDs) and subsequently maps those PRDs into structured Azure DevOps (ADO) work items using a local Sprintly API gateway.

---

## Directory Structure

The workspace is organized into three main skill directories:

```text
skills/
├── azdo-work-items/          # Low-level ADO work item CRUD via Sprintly API
│   ├── agents/               # Skill configuration for agents
│   ├── references/           # Sprintly REST API endpoint reference
│   └── scripts/              # PowerShell helper for single work item creation
│
├── to-azdo/                  # Tooling to convert PRD specs to ADO work items
│   ├── agents/               # Skill configuration for agents
│   ├── references/           # Mapping rules (PRD to features, stories, tasks)
│   └── scripts/              # PowerShell script for bulk PRD import
│
└── to-prd/                   # Skill to synthesize context into standard PRDs
```

---

## Codex Skills & Workflows

### 1. `to-prd` (Context to PRD)
* **Purpose**: Synthesizes the current conversation context, codebase state, and test seams into a structured Markdown PRD.
* **Template Sections**:
  - Problem Statement
  - Solution
  - User Stories (numbered list)
  - Implementation Decisions (modules, interfaces, contracts; no file paths)
  - Testing Decisions (modules to test, expected behavior, prior art)
  - Out of Scope
  - Further Notes
* **Action**: Once finalized, it publishes the PRD to the issue tracker and triggers the `$to-azdo` flow to generate the corresponding work items.

### 2. `to-azdo` (PRD to Azure DevOps)
* **Purpose**: Converts a PRD document (Markdown or JSON) into a hierarchy of Azure DevOps work items.
* **Hierarchy**:
  1. **Feature**: Represents the full PRD. Contains the problem statement, solution, and scope.
  2. **User Story / Product Backlog Item (PBI)**: One per user story found in the PRD.
  3. **Task**: Actionable engineering and testing items derived from implementation/testing decisions.
* **Rules**:
  - Iteration path is automatically mapped to the current active sprint of the project.
  - Omit assignees unless explicitly requested or defined.
  - Only create Tasks for actionable keywords (e.g., *build, add, update, implement, integrate, validate, test, migrate, expose, persist, remove, refactor*).

### 3. `azdo-work-items` (Direct Azure DevOps Actions)
* **Purpose**: Directly interacts with Sprintly's endpoints to query projects, iterations, members, work item types/states, and handle updates, comments, or links.
* **Git History Integration**: Allows creating work items directly from a commit range or Git history by analyzing diffs (`git show --stat --patch`) rather than relying solely on commit messages.

---

## PowerShell Helper Scripts

### Single Work Item Creation
Located at: `azdo-work-items/scripts/create_work_item.ps1`

Allows creating a single work item of any valid type (e.g., Task, Bug, User Story) directly from the command line:
```powershell
.\azdo-work-items\scripts\create_work_item.ps1 `
  -ProjectId "MyProject" `
  -Title "Add Export Button" `
  -Type "Task" `
  -Description "Create an export button on the main dashboard." `
  -IterationPath "MyProject\\Sprint 1"
```

### Batch PRD Work Item Import
Located at: `to-azdo/scripts/create_prd_work_items.ps1`

Parses a PRD document and automatically builds the Feature -> User Story -> Task hierarchy in your target Azure DevOps project:
```powershell
.\to-azdo\scripts\create_prd_work_items.ps1 `
  -ProjectId "MyProject" `
  -PrdPath ".\feature.prd.md" `
  -StoryType "User Story"
```
*Use `-PlanOnly` to preview the planned hierarchy in JSON format before executing write operations.*

---

## Setup & Configuration

1. **Sprintly Backend**: Ensure the local backend service is running. By default, the scripts and skills target `http://localhost:8181`.
   - If not running, start it from the backend project: `dotnet run`.
2. **Azure DevOps Environment Variables**: Ensure the backend is configured with valid Azure DevOps connection details (typically in `appsettings.Development.json` or via environment variables):
   - `AZDO_BASE_URL`
   - `AZDO_ORG`
   - `AZDO_PAT` (Personal Access Token)
   - `AZDO_API_VERSION`
