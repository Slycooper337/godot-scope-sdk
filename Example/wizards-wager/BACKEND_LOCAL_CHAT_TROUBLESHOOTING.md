# Troubleshooting: Local General Chat Returns “Unable to send the chat message”

## Symptom

In the Godot client, enter a non-empty General message while connected to the
`forest` world. The client displays:

```text
Unable to send the chat message.
```

This is the backend's generic `chat_message_rejected` response with
`reason_code: "invalid_request"`. It is different from a client transport
failure: the WebSocket accepted the command and returned a structured chat
response.

## Known-good client protocol

The current Godot client sends this authenticated WebSocket command through
`Scope.realtime.send_command`:

```json
{
  "type": "send_chat_message",
  "data": {
    "channel_type": "general",
    "text": "Hello from Forest",
    "client_message_id": "<current-user-id>-<ticks>-<sequence>"
  }
}
```

It does **not** send the application ID, sender ID, world ID, map ID,
recipients, timestamps, or bubble configuration. Those values must come from
the authenticated connection and its authoritative joined area.

Relevant frontend files:

```text
Example/wizards-wager/game.gd
Example/wizards-wager/chat_dock.gd
```

The Godot project is configured to use this API base URL:

```text
http://44.200.163.88:8080
```

The SDK converts that to a WebSocket connection at:

```text
ws://44.200.163.88:8080/realtime
```

## Expected successful sequence

1. The socket authenticates successfully.
2. The client sends `join_area` with `{ "map_id": "forest" }`.
3. The server successfully resolves a world ID, sets the connection area, and
   returns `world_snapshot` followed by `chat_channels_available`.
4. The client sends `send_chat_message`.
5. The server returns `chat_message_accepted` to the sender.
6. The server sends `chat_message` to every socket in the same application,
   world, and map—including the sender.

If step 4 returns `chat_message_rejected` with the generic text in the
symptom, the error occurred inside `chat.Send`, but was not a typed
`chat.RejectionError`.

## First checks: deployment and schema

Run these checks against the **deployed** backend and database, not merely the
local checkout.

1. Confirm the running service image includes commit `ff536ca` (Messenger
   System), specifically the `send_chat_message` branch in
   `api/internal/realtime/handler.go`.
2. Confirm migration `000029_add_authoritative_local_chat.up.sql` has run in
   the deployment database.
3. Confirm the following tables exist in that same database:

   ```text
   chat_messages
   chat_user_restrictions
   chat_blocked_terms
   ```

4. Confirm the running backend was restarted after the image and migration
   change; a migrated database with an old API image is not sufficient.
5. Confirm the deployed service can connect to its database with write access
   for `chat_messages`.

Useful PostgreSQL checks:

```sql
SELECT version
FROM schema_migrations
WHERE version = 29;

SELECT to_regclass('public.chat_messages') AS chat_messages,
       to_regclass('public.chat_user_restrictions') AS chat_user_restrictions,
       to_regclass('public.chat_blocked_terms') AS chat_blocked_terms;
```

Adjust the migration metadata query if this deployment uses a migration table
other than `schema_migrations`.

## Check the joined area before blaming chat

`sendChatMessage` derives scope from `connection.currentArea()`. A valid
General message therefore requires non-empty values for all of:

```text
application ID
world ID
map ID
```

Before reproducing, inspect the WebSocket stream for:

```json
{
  "type": "world_snapshot",
  "channel": "world/forest"
}
```

and then:

```json
{
  "type": "chat_channels_available",
  "data": {
    "channels": [
      {
        "channel_type": "general",
        "scope_kind": "map",
        "scope_id": "forest"
      }
    ]
  }
}
```

If either is absent, investigate `join_area`, world configuration, and area
resolution first. Do not attempt to repair the scope by trusting location data
from the client.

## Determine the precise rejected response

Capture the complete server response for the failed send. It must include the
actual `type`, `error`, and `data` fields. These cases have different owners:

| Response | Meaning | Next investigation |
|---|---|---|
| `type: "error", error: "unsupported command"` | Old API image | Redeploy commit `ff536ca`. |
| `chat_message_rejected`, `channel_unavailable` | `h.chat` is nil or chat is disabled | Verify chat repository/service construction and dependency injection. |
| `chat_message_rejected`, `not_in_area` | Socket lacks a valid area | Fix `join_area`/world configuration; inspect current connection area. |
| `chat_message_rejected`, `muted` or `moderated` | Policy deliberately blocked the message | Inspect user restriction/blocked-term data. |
| `chat_message_rejected`, `invalid_request`, message `Unable to send the chat message.` | Unclassified service/database error | Inspect server logs and add error logging around `h.chat.Send`. |

The reported symptom is the last row. It should be treated as an observability
gap: the handler currently hides the underlying error before the client can
show it.

## Required server-side logging for this incident

Temporarily add structured logging immediately before and after `h.chat.Send`
in `sendChatMessage`. Do not log message text or credentials.

Log:

```text
application_id
user_id
channel_type
client_message_id
world_id
map_id
duplicate
error type
error text
```

Suggested shape:

```go
message, duplicate, err := h.chat.Send(ctx, scope, connection.UserID, input)
if err != nil {
    log.Printf(
        "realtime: chat send failed app=%s user=%d channel=%s client_message_id=%s world=%s map=%s error=%T: %v",
        appID, connection.UserID, input.ChannelType, input.ClientMessageID,
        worldID, mapID, err, err,
    )
    // Existing typed rejection handling follows.
}
```

With this in place, reproduce once and provide the resulting log line. The
most likely underlying errors are a missing `chat_messages` table, missing
repository dependency, a database permission error, or deployment code/schema
version drift.

## Verify data and policy state

For the reproducing account and application, check:

```sql
SELECT application_id, user_id, is_banned, muted_until, reason
FROM chat_user_restrictions
WHERE application_id = :application_id
  AND user_id = :user_id;

SELECT application_id, term, enabled
FROM chat_blocked_terms
WHERE application_id = :application_id
ORDER BY term;
```

Also verify that the application ID used by the game matches the server's
registered application and that the authenticated user is valid for it.

## Reproduction using a WebSocket client

Use the same application/public-key/JWT headers as the Godot client. Send the
commands in this order on a single socket:

```json
{"type":"join_area","data":{"map_id":"forest"}}
```

Wait for `world_snapshot`, then:

```json
{"type":"send_chat_message","data":{"channel_type":"general","text":"chat smoke test","client_message_id":"backend-smoke-001"}}
```

Expected success:

```json
{"type":"chat_message_accepted","data":{"client_message_id":"backend-smoke-001","message_id":"...","created_at":"..."}}
```

followed by:

```json
{"type":"chat_message","channel":"chat/general","data":{"channel_type":"general","scope_id":"forest","text":"chat smoke test","bubble":{"enabled":true,"lifetime_seconds":6}}}
```

If the direct WebSocket reproduction fails identically, the issue is entirely
server/deployment-side. If it succeeds while Godot fails, provide the Godot
socket traffic and the server request log for the same attempt.

## Follow-up fixes once sending succeeds

These are not the cause of the current rejection, but should be completed:

1. Wire the client to `get_chat_history`, since this backend intentionally
   exposes history over WebSocket rather than HTTP.
2. Add an authenticated realtime end-to-end test asserting acknowledgement and
   area broadcast delivery.
3. Clear a connection's previous area when a subsequent `join_area` fails, so
   an invalid join cannot retain old-area chat eligibility.
4. Keep the detailed server error in logs, while returning the current safe,
   user-facing generic error to the client.
