# Sprintly Backend Azure DevOps API

Default local backend URL: `http://localhost:8181`.

## Endpoints

- `GET /api/health` returns backend status.
- `GET /api/projects` lists Azure DevOps projects as `{ id, name, description, state, lastUpdateTime }`.
- `GET /api/projects/{projectId}/iterations` lists team iterations as `{ id, name, path }`.
- `GET /api/projects/{projectId}/members` lists members as `{ displayName, uniqueName }`.
- `GET /api/projects/{projectId}/workitemtypes/{type}/states` lists valid states for a work item type.
- `POST /api/projects/{projectId}/workitems` creates a work item.
- `PATCH /api/projects/{projectId}/workitems/{id}` updates fields using Azure DevOps field names.
- `GET /api/projects/{projectId}/workitems/{id}` returns full detail.
- `POST /api/projects/{projectId}/workitems/{id}/comments` adds a comment with `{ "text": "..." }`.
- `POST /api/projects/{projectId}/workitems/{id}/links` adds a related work item or hyperlink.

## Create Work Item

`POST /api/projects/{projectId}/workitems`

```json
{
  "title": "Required title",
  "type": "Task",
  "description": "Optional description",
  "assignedTo": "user@example.com",
  "parentId": 12345,
  "iterationPath": "Project\\Sprint 1"
}
```

Required fields: `title`, `type`.

Optional fields: `description`, `assignedTo`, `parentId`, `iterationPath`.

Backend behavior:

- Uses Azure DevOps JSON Patch internally.
- Adds `System.Title` always.
- Adds `System.Description`, `System.AssignedTo`, and `System.IterationPath` only when non-empty.
- Adds parent relation `System.LinkTypes.Hierarchy-Reverse` when `parentId` is greater than zero.
- Returns a `BoardWorkItem`.

Response shape:

```json
{
  "id": 1001,
  "title": "Required title",
  "state": "New",
  "type": "Task",
  "assignedTo": "User Name",
  "priority": "-",
  "tags": "",
  "createdDate": "2026-06-09T00:00:00Z",
  "changedDate": "2026-06-09T00:00:00Z",
  "iterationPath": "Project\\Sprint 1",
  "boardColumn": "New",
  "parentId": 12345
}
```

## Update Fields

`PATCH /api/projects/{projectId}/workitems/{id}` accepts a JSON object where keys are Azure DevOps field names:

```json
{
  "System.Title": "Updated title",
  "System.State": "Active",
  "System.AssignedTo": "user@example.com",
  "System.IterationPath": "Project\\Sprint 1",
  "System.Description": "Updated description"
}
```

## Comments

`POST /api/projects/{projectId}/workitems/{id}/comments`

```json
{ "text": "Implementation note or acceptance detail." }
```

## Links

`POST /api/projects/{projectId}/workitems/{id}/links`

To link another work item, pass the target id as `url`:

```json
{
  "rel": "System.LinkTypes.Related",
  "url": "12345",
  "comment": "Related implementation task"
}
```

To link an external URL, pass the URL:

```json
{
  "rel": "Hyperlink",
  "url": "https://example.com/spec",
  "comment": "Specification"
}
```

## Troubleshooting

- If `/api/health` fails, start the backend from `backend` with `dotnet run`; this repo binds to `http://localhost:8181`.
- If Azure DevOps calls fail, check `AZDO_BASE_URL`, `AZDO_ORG`, `AZDO_PAT`, and `AZDO_API_VERSION` in environment variables or `backend/appsettings.Development.json`.
- Prefer project name when the user gives a display name; the backend resolves several endpoints by project name or id.
- Use exact iteration `path`, not iteration `name`, for `iterationPath`.
