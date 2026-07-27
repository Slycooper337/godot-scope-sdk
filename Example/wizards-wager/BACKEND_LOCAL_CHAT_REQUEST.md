# Backend Request: Authoritative Local General Chat

## Goal

Add the first World-of-Warcraft-style chat channel for `wizards-wager`:

- Players can send messages through a bottom-right **General** chat panel.
- Messages are delivered only to players in the sender's current local world area.
- Every delivered message also causes a temporary white speech bubble above the sender for every recipient who received it.
- The server is authoritative for identity, channel availability, area membership, recipients, timestamps, rate limits, and moderation validation.

This request establishes a channel framework that can later add LFG and Market without changing the transport contract.

## Scope for the first release

Implement only this channel:

| Field | Value |
|---|---|
| `channel_type` | `general` |
| availability | Any player currently joined to a world area |
| audience | Connected players in the same `application_id`, `world_id`, and `map_id` |
| initial map | `forest` |
| history | Most recent 100 messages for the current General scope |
| bubble lifetime | 6 seconds, supplied by the server |

The map is the initial local-chat area. Do not trust a client-provided map, area, sender ID, username, or bubble duration. The backend must derive the scope from the authenticated socket's authoritative `join_area` state.

When a future map has named towns, districts, or instances, the server may refine the `scope_id` to that smaller area without changing the client event schema.

## Client commands

### Send a message

The Godot client will send this authenticated realtime command:

```json
{
  "type": "send_chat_message",
  "data": {
    "channel_type": "general",
    "text": "Anyone want to group up?",
    "client_message_id": "7-1722012345678-1"
  }
}
```

Rules:

- `client_message_id` is an opaque idempotency key generated per sender. It is not a server message ID.
- `text` is plain text. The client will trim it, but the backend must trim and validate again.
- The command must not accept `sender_id`, `sender_username`, `application_id`, `world_id`, `map_id`, `scope_id`, recipients, timestamp, or bubble data.

### Retrieve visible-channel history

Provide an authenticated HTTP endpoint, or equivalent SDK-supported endpoint:

```text
GET /chat/channels/general/messages?limit=100
```

The server derives the caller's current scope from their active area membership. Return newest-first or oldest-first consistently; document the ordering. The proposed response is oldest-first:

```json
{
  "channel": {
    "channel_type": "general",
    "display_name": "General",
    "scope_kind": "map",
    "scope_id": "forest"
  },
  "messages": []
}
```

Return an empty list for a valid scope with no history. Return a clear 409/422-style error when the player is not currently joined to a chat-enabled area.

## Server processing and authorization

Add `send_chat_message` to the realtime handler. In a transaction or similarly race-safe operation:

1. Authenticate the socket and obtain the user and application from the session.
2. Resolve the player's active authoritative world membership created by `join_area`.
3. Reject the command if the player has no active membership, is in an invalid/disconnected map state, or `general` is unavailable there.
4. Normalize text with server-side Unicode-safe trimming; reject blank messages.
5. Enforce a maximum of **500 Unicode characters** after normalization.
6. Apply the application's profanity/moderation policy before persistence or broadcast. Reject muted/banned users.
7. Apply a server-side per-player rate limit: **5 accepted messages per 10 seconds**, with a maximum burst of 3 in 2 seconds. Use server time.
8. Deduplicate retries by `(application_id, sender_id, client_message_id)`. A duplicate must return the original accepted message/acknowledgement and must not create or broadcast another message.
9. Persist the accepted message with a server-generated immutable ID and server timestamp.
10. Resolve recipients from currently connected sockets in the same application, world, and map scope. Never accept a recipient list from the client.
11. Publish the resulting event exactly once to each eligible recipient socket, including the sender.

Position is not needed for the first General channel because the requested local scope is the joined map/area. Keep recipient selection behind a chat-audience resolver so a later true-radius channel can additionally use authoritative server-tracked player positions.

## Realtime responses and events

### Accepted acknowledgement

Send this only to the originating socket. It allows the client to clear a pending-send state without locally inventing a chat message:

```json
{
  "type": "chat_message_accepted",
  "data": {
    "client_message_id": "7-1722012345678-1",
    "message_id": "chat_01J...",
    "created_at": "2026-07-26T18:00:00Z"
  }
}
```

### Delivered chat message

Publish this to every eligible recipient, including the sender:

```json
{
  "type": "chat_message",
  "data": {
    "message_id": "chat_01J...",
    "channel_type": "general",
    "channel_display_name": "General",
    "scope_kind": "map",
    "scope_id": "forest",
    "sender_id": 7,
    "sender_username": "SlyCooper",
    "text": "Anyone want to group up?",
    "created_at": "2026-07-26T18:00:00Z",
    "bubble": {
      "enabled": true,
      "lifetime_seconds": 6
    }
  }
}
```

The Godot frontend will use this one server event for both the transcript and the world-space speech bubble. It will only show a bubble when the sender's local or remote player entity exists in the current scene; missing entities must not prevent the transcript from displaying.

### Rejected message

Send this only to the originator:

```json
{
  "type": "chat_message_rejected",
  "data": {
    "client_message_id": "7-1722012345678-1",
    "reason_code": "rate_limited",
    "message": "You are sending messages too quickly.",
    "retry_after_seconds": 2
  }
}
```

Use stable `reason_code` values: `not_in_area`, `channel_unavailable`, `empty`, `too_long`, `rate_limited`, `muted`, `moderated`, and `invalid_request`.

## Storage and retention

Add a chat-message store with at least:

```text
id
application_id
channel_type
scope_kind
scope_id
sender_id
sender_username_snapshot
text
client_message_id
created_at
moderation_state
```

Requirements:

- Unique index on `(application_id, sender_id, client_message_id)` when the client ID is present.
- Index history queries by `(application_id, channel_type, scope_kind, scope_id, created_at)`.
- Retain General history for at least 24 hours initially; the endpoint returns only the latest 100 entries.
- Store the username snapshot used at send time so historical chat remains readable if a player later renames their account.
- Do not expose direct-message records through this endpoint; this feature is separate from the existing private messages service.

## Channel framework for follow-up work

Implement channel policy as data/configuration or a small server-owned resolver, not a `general`-only conditional spread through the realtime handler. It needs to support this shape:

| Future channel | Intended scope | Expected additional policy |
|---|---|---|
| `lfg` | world or region | optional level/queue rules and slower rate limit |
| `market` | market town/district | only available in designated market areas; anti-spam controls |

The client should be able to request an authoritative list of currently available channels, either included in the successful `join_area` response/event or with:

```text
GET /chat/channels/available
```

For the first release this returns General only. Keep `channel_type`, `scope_kind`, and `scope_id` in every response/event from day one.

## Non-goals

- Do not add private messages, party chat, guild chat, whispers, emotes, links, item payloads, rich text, or client-selected recipients.
- Do not use generic client-published realtime events as the authority mechanism for chat.
- Do not broadcast General chat to every online user regardless of map/area.
- Do not send a speech-bubble-only event; the delivered `chat_message` is the single source of truth.

## Required tests

1. An authenticated player joined to `forest` can send a valid General message and receives one acknowledgement plus one delivered event.
2. Other connected players in the same application, world, and `forest` map receive exactly one delivered event.
3. Players in another map, world, application, or no active area membership receive no event.
4. A forged sender, map, scope, recipient list, timestamp, or bubble duration is ignored/rejected because those fields are not accepted from the client.
5. Blank/whitespace-only, oversized, malformed, muted, and moderated messages are rejected with the specified stable reason codes.
6. Rate limits reject excess messages without persisting or broadcasting them; `retry_after_seconds` is returned.
7. Repeating the same `client_message_id` creates and broadcasts only one stored message.
8. History returns at most 100 messages for the caller's current General scope and never leaks messages from another scope/application.
9. History uses the stored username snapshot and server timestamp.
10. Disconnecting, reconnecting, or changing map removes old audience eligibility immediately; the player only receives events after valid new area membership is established.
11. Existing presence, `join_area`, movement, authoritative world, private-message, and realtime subscription tests remain passing.

