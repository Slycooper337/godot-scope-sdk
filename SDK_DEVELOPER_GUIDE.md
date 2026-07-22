# Scope SDK Developer Guide

Scope gives a Godot project access to authentication and persistent data without requiring game code to manage HTTP, JWTs, headers, or JSON responses.

## 1. Install the SDK

Copy the `addons/scope_platform` folder into your Godot project so the project contains:

```text
res://addons/scope_platform/plugin.cfg
```

In Godot, open **Project > Project Settings > Plugins** and enable **Scope Platform**. Enabling the plugin registers the `Scope` autoload and adds the Scope project settings.

## 2. Configure Project Settings

Open **Project > Project Settings** and set:

| Setting | Purpose |
| --- | --- |
| `scope_platform/api_url` | Scope backend URL, such as `https://api.example.com` |
| `scope_platform/application_id` | Application identifier supplied by Scope |
| `scope_platform/public_key` | Application public key supplied by Scope |
| `scope_platform/request_timeout` | HTTP timeout in seconds; defaults to `30` |
| `scope_platform/debug_logging` | Logs Scope requests and response codes; defaults to `true` |

Game code should not configure these values or construct an HTTP client.

## 3. Initialize Scope

Initialize once when the game starts, before using any service:

```gdscript
func _ready() -> void:
	var result := await Scope.initialize()
	if not result.success:
		push_error(result.error)
		return

	if Scope.session.logged_in:
		load_game()
	else:
		show_login()
```

Initialization loads the project settings, creates the SDK services, restores a saved session when available, validates it with the backend, and makes the current user available through `Scope.session.current_user`.

## 4. Log in and restore sessions

Call login after initialization:

```gdscript
var result := await Scope.auth.login(email, password)
if not result.success:
	show_error(result.error)
	return

var user: ScopeUser = result.data
```

Successful login saves the JWT automatically. On the next launch, `Scope.initialize()` restores and validates it. Invalid or expired sessions are cleared and the SDK starts logged out.

To log out:

```gdscript
Scope.auth.logout()
```

The compatibility wrappers `Scope.login()`, `Scope.register()`, `Scope.logout()`, and `Scope.me()` are also available, but the service API is preferred for new code.

## 5. Read and write user records

User records are the default database scope:

```gdscript
var result := await Scope.database.get("player")
if result.success:
	var player: ScopeDatabaseRecord = result.data
	print(player.data.get("coins", 0))
else:
	show_error(result.error)
```

Write a record with a dictionary:

```gdscript
var result := await Scope.database.set("player", {
	"coins": 100,
	"level": 3
})

if not result.success:
	show_error(result.error)
```

Delete it when needed:

```gdscript
var result := await Scope.database.delete("player")
```

## 6. Read and write shared records

Shared records use explicit helpers so they are never confused with player-specific data:

```gdscript
var result := await Scope.database.get_shared("game_settings")
if result.success:
	var settings: ScopeDatabaseRecord = result.data
	apply_settings(settings.data)
```

```gdscript
await Scope.database.set_shared("game_settings", {
	"season": "summer",
	"double_xp": true
})
```

Use `get_shared`, `set_shared`, and `delete_shared` for shared records.

## 7. Handle errors with ScopeResponse

Every service returns the same `ScopeResponse` object:

```gdscript
var result := await Scope.database.get("player")

if result.success:
	var record: ScopeDatabaseRecord = result.data
	use_record(record)
	return

push_error("Scope request failed (%d): %s" % [result.status, result.error])
```

Use `success` to branch, `data` for the typed result, `error` for a user-facing or loggable message, and `status` when the HTTP status matters. Game code should not parse backend response dictionaries.

## 8. Best practices

- Initialize Scope once and wait for it before calling `auth` or `database`.
- Keep one document per game system—for example, `player`, `inventory`, `quests`, or `settings`—instead of storing the entire game state in one oversized record.
- Use user records for player-specific state and shared records only for data intentionally shared by players.
- Check `result.success` after every request and handle failures near the call site.
- Keep Scope calls in small system-specific classes so scenes stay focused on presentation and gameplay.
- Leave request URLs, headers, tokens, and serialization to the SDK.
