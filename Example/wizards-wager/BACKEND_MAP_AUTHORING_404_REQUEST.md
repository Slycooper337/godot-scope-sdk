# Backend Error Request: Map Validation Endpoint Returns 404

## Observed error

The Godot Map Authoring editor reaches the backend, but **Validate With
Backend** returns HTTP `404`.

The frontend SDK constructs the request as:

```text
POST {ScopeConfig.api_url()}/worlds/main_world/maps/forest/validate
```

Request body:

```json
{
  "definition": {
    "map_id": "forest",
    "world_id": "main_world",
    "version": 0,
    "coordinate_system": "godot_2d",
    "physics_surfaces": [],
    "combatant_spawns": []
  }
}
```

The SDK also constructs these related routes:

```text
GET  {ScopeConfig.api_url()}/worlds/main_world/maps/forest/definition
PUT  {ScopeConfig.api_url()}/worlds/main_world/maps/forest/definition
GET  {ScopeConfig.api_url()}/worlds/main_world/maps/forest/versions
```

## Request to backend engineer

Please verify that the deployed API registers the routes above under the same
base URL configured in `ScopeConfig.api_url()`.

Specifically confirm:

1. The route group is registered in the deployed service, not only locally.
2. The deployed image includes the map-authoring handler and migrations.
3. The actual route prefix matches the SDK base URL. For example, determine
   whether the service expects:

   ```text
   /worlds/...
   /api/worlds/...
   /v1/worlds/...
   ```

   `ScopeConfig.api_url()` should point to the prefix immediately before
   `/worlds/...`.
4. The `POST /validate` method is registered separately from the `GET` and
   `PUT` definition methods.
5. The route accepts authenticated requests with the existing Scope headers.
6. The deployment has the map-definition storage schema applied.
7. A missing map record returns `404` only for a valid route; it must not be
   confused with an unregistered route.

## Expected status behavior

For a valid route:

```text
POST /worlds/main_world/maps/forest/validate
200 or 204  valid definition
422          field-level validation errors
401/403      authentication or authorization failure
```

For publishing:

```text
PUT /worlds/main_world/maps/forest/definition
200/201      published version
409          stale expected_version
422          field-level validation errors
```

The frontend sends the publish body as:

```json
{
  "expected_version": 0,
  "definition": {}
}
```

For an existing map, the frontend sends the current published version instead
of `0`.

## Expected end-to-end flow

The intended editor flow is:

1. Local Godot validation runs.
2. `POST /worlds/{world_id}/maps/{map_id}/validate` validates the complete
   definition without saving it.
3. The editor optionally calls
   `GET /worlds/{world_id}/maps/{map_id}/definition` to refresh the current
   published version.
4. The editor calls `PUT /worlds/{world_id}/maps/{map_id}/definition` with
   `expected_version` and the complete definition.
5. The backend validates again, assigns the next monotonic version, stores
   rollback history, and returns the published version.
6. Runtime world snapshots/events include that map version and behavior
   metadata.

## Useful backend diagnostics

Please provide:

- the deployed route listing or equivalent;
- the exact public API base URL expected by the Godot client;
- one successful curl/API example for the validate route;
- the deployed service/image version;
- whether the map-definition migration ran successfully;
- the response body currently returned with the `404`.

## Acceptance check

Using the configured deployed API URL, this request must reach the map handler
and return validation output rather than a route-not-found response:

```bash
curl -i -X POST \
  "$API_BASE/worlds/main_world/maps/forest/validate" \
  -H "Content-Type: application/json" \
  -H "X-Scope-Application-ID: $SCOPE_APPLICATION_ID" \
  -H "X-Scope-Public-Key: $SCOPE_PUBLIC_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --data '{"definition":{"map_id":"forest","world_id":"main_world","version":0,"coordinate_system":"godot_2d","physics_surfaces":[],"combatant_spawns":[]}}'
```
