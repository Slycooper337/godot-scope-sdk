# Scope Platform Godot SDK

A Godot 4 addon for connecting a game to Scope Platform services.

The addon provides:

- Application-scoped authentication
- Persistent login sessions
- User and shared database records
- Read-only leaderboards
- Wizards Wager betting, profiles, balances, and bet history
- Friends and messaging
- Notifications
- Achievements
- Realtime WebSocket presence
- File storage
- Analytics batching

The main entry point is the Scope autoload:

    await Scope.initialize()
    var result: ScopeResponse = await Scope.auth.login(email, password)

## Requirements

- Godot 4.x
- A running Scope Platform backend
- An application ID
- A public application key
- The backend URL

The public key may be included in the client. Never include a Scope service key, administrative key, or SCOPE_SERVICE_KEY in a Godot project.

## Installation

Copy the complete addons/scope_platform folder into the new project:

    your-project/
      addons/
        scope_platform/
          plugin.cfg
          plugin.gd
          scope_platform.gd
          ...

Open the project in Godot and enable the plugin:

1. Open Project > Project Settings.
2. Select Plugins.
3. Enable Scope Platform.
4. Confirm that the Scope autoload was added.

Enabling the plugin registers the Scope settings and creates this autoload:

    Name: Scope
    Path: res://addons/scope_platform/scope_platform.gd

If the plugin cannot be enabled, add the autoload manually with that name and path.

The addon expects all SDK scripts to remain under:

    res://addons/scope_platform

## Configuration

The plugin registers these settings:

    scope_platform/api_url
    scope_platform/application_id
    scope_platform/public_key
    scope_platform/request_timeout
    scope_platform/debug_logging

Example project settings:

    scope_platform/api_url = "http://localhost:8080"
    scope_platform/application_id = "my-game"
    scope_platform/public_key = "your-public-key"
    scope_platform/request_timeout = 30
    scope_platform/debug_logging = true

The setting names use slashes in Godot:

    ProjectSettings.set_setting("scope_platform/api_url", "http://localhost:8080")
    ProjectSettings.set_setting("scope_platform/application_id", "my-game")
    ProjectSettings.set_setting("scope_platform/public_key", "your-public-key")

For Wizards Wager, use the backend-provided URL, application ID, and public key.

The public key is intentionally client-visible. Do not put any of these in the client:

- SCOPE_SERVICE_KEY
- Administrative credentials
- Job credentials
- Trusted leaderboard score-submission credentials

## Initialization

Initialize the SDK before using any service:

    extends Node

    func _ready() -> void:
        var result: ScopeResponse = await Scope.initialize()
        if not result.success:
            push_error("Scope initialization failed: " + result.error)
            return

        print("Scope is ready")

Initialization:

1. Creates the internal HTTP request service.
2. Restores a saved JWT from user://scope/session.json, if one exists.
3. Validates a restored session with GET /auth/me.
4. Clears an unauthorized or forbidden session.
5. Creates all SDK services.

Call Scope.initialize once during startup. It is safe to call again; an already initialized SDK returns a successful response.

## Authentication

Register:

    var result: ScopeResponse = await Scope.auth.register(
        "player@example.com",
        "player_name",
        "password"
    )

    if result.success:
        var user: ScopeUser = result.data
        print("Registered as " + user.username)
    else:
        print("Registration failed: " + result.error)

Login:

    var result: ScopeResponse = await Scope.auth.login(
        "player@example.com",
        "password"
    )

    if result.success:
        var user: ScopeUser = result.data
        print("Logged in as " + user.username)

The SDK stores the returned JWT and automatically adds these headers to future requests:

    X-Scope-Application-ID
    X-Scope-Public-Key
    Authorization: Bearer <jwt>

Restore and validate a session:

    if Scope.is_logged_in():
        var result: ScopeResponse = await Scope.auth.me()
        if result.success:
            var user: ScopeUser = result.data
            print(user.username)

Useful session properties:

    Scope.session.current_user
    Scope.current_user()
    Scope.session.get_access_token()

Do not display or log the access token.

Check a username:

    var result: ScopeResponse = await Scope.auth.username_available("new_name")
    if result.success:
        var data: Dictionary = result.data
        var available: bool = bool(data.get("available", false))

Logout:

    Scope.auth.logout()
    get_tree().change_scene_to_file("res://login.tscn")

## ScopeResponse

Every asynchronous service method returns ScopeResponse.

Important fields:

    result.success       # true for a successful 2xx response
    result.status        # HTTP status code
    result.data          # decoded response data
    result.error         # error message when unsuccessful

Aliases and helpers:

    result.status_code
    result.message
    result.is_success()
    result.has_data()

Recommended handling:

    var result: ScopeResponse = await Scope.database.read("preferences")

    if not result.success:
        match result.status:
            401, 403:
                print("Authentication or membership problem")
            404:
                print("Record does not exist")
            409:
                print("Conflict")
            _:
                print("Scope error: " + result.error)
        return

    var record: ScopeDatabaseRecord = result.data
    print(record.data)

A successful empty list is still success:

    result.success == true
    result.status == 200
    result.data is Array

Display an empty-state message for 200 [] instead of treating it as an error.

A 404 is endpoint-specific. Examples:

- Database read: the record does not exist.
- Current wager: there is no active wager.
- A list endpoint: the resource may be missing, depending on the backend contract.

Always inspect result.status before deciding how to display a 404.

## Database

Use the generic database for non-authoritative data:

- Preferences
- UI settings
- Cosmetic choices
- Tutorial progress
- Local configuration

The public interface is read, write, and remove.

### User-scoped records

Write:

    var result: ScopeResponse = await Scope.database.write(
        "preferences",
        {
            "music_enabled": true,
            "language": "en"
        }
    )

    if result.success:
        var record: ScopeDatabaseRecord = result.data

Read:

    var result: ScopeResponse = await Scope.database.read("preferences")

    if result.success:
        var record: ScopeDatabaseRecord = result.data
        var music_enabled: bool = bool(record.data.get("music_enabled", true))
    elif result.status == 404:
        print("Preferences have not been created yet")

Delete:

    await Scope.database.remove("preferences")

The SDK sends:

    GET /database/preferences?scope=user
    DELETE /database/preferences?scope=user

A write is wrapped as:

    {
      "scope": "user",
      "data": {
        "music_enabled": true
      }
    }

### Shared records

Shared records are application-wide:

    await Scope.database.write_shared(
        "settings",
        {"maintenance": false}
    )

    var result: ScopeResponse = await Scope.database.read_shared("settings")
    await Scope.database.remove_shared("settings")

Do not use generic Database for authoritative:

- Gold
- Wagers
- Inventory
- Permissions
- Leaderboard scores
- Anti-cheat state

Clients can access and modify generic database records according to backend permissions. Authoritative values must come from protected backend services.

## Leaderboards

The client may read leaderboards:

    var result: ScopeResponse = await Scope.leaderboards.top("gold", 100)

    if result.success:
        var entries: Array = result.data

    var rank_result: ScopeResponse = await Scope.leaderboards.rank("gold")

These call:

    GET /leaderboards/gold?limit=100
    GET /leaderboards/gold/rank

The client SDK does not submit scores. Score submission must happen in trusted server-side logic using a server-only service key.

## Wizards Wager

Wizards Wager is server-authoritative. The client requests state and displays it.

### Place a bet

    var result: ScopeResponse = await Scope.wizards_wager.place_bet(25, "heads")

    if result.success:
        var bet: ScopeWizardsWagerBet = result.data
        print("Bet placed on " + bet.choice)
    else:
        print("Bet failed: " + result.error)

The SDK validates heads and tails locally and sends:

    {
      "amount": 25,
      "choice": "heads"
    }

The server validates the choice again.

The frontend must never:

- Deduct gold locally as the source of truth
- Resolve the coin flip
- Choose a random result
- Schedule the resolution job
- Submit arbitrary leaderboard scores

### Balance

    var result: ScopeResponse = await Scope.wizards_wager.balance()

    if result.success:
        var wallet: ScopeWizardsWagerWallet = result.data
        print(wallet.gold)

### Active bet

    var result: ScopeResponse = await Scope.wizards_wager.current_bet()

    if result.success:
        var bet: ScopeWizardsWagerBet = result.data
    elif result.status == 404:
        print("No active bet")

Use the server-provided bet.resolves_at as the countdown source. Calculate remaining time from an absolute timestamp. Do not simply subtract one second from a stored display value.

When the countdown reaches zero, refresh:

    Scope.wizards_wager.current_bet()
    Scope.wizards_wager.balance()

### History

    var result: ScopeResponse = await Scope.wizards_wager.history(50)

    if result.success:
        var bets: Array[ScopeWizardsWagerBet] = result.data
        for bet: ScopeWizardsWagerBet in bets:
            print("%d on %s: %s (%s)" % [
                bet.amount,
                bet.choice,
                bet.status,
                bet.result
            ])

This calls:

    GET /wizards-wager/bets/history?limit=50

History includes:

- amount
- choice
- result
- status
- resolves_at
- resolved_at

Older bets may return choice = "unknown".

### Other player profile

    var result: ScopeResponse = await Scope.wizards_wager.player_profile(user_id)

    if result.success:
        var profile: ScopeWizardsWagerPlayerProfile = result.data
        print(profile.username)
        print(profile.gold)
        print(profile.online)

Gold and online status are returned by the server. Do not infer another player's values locally.

## Friends

List accepted friends:

    var result: ScopeResponse = await Scope.friends.list()

    if result.success:
        var friends: Array[ScopeFriend] = result.data

Send a request by username:

    var result: ScopeResponse = await Scope.friends.send_request("other_player")

List requests:

    var incoming: ScopeResponse = await Scope.friends.requests()
    var outgoing: ScopeResponse = await Scope.friends.requests("outgoing")

Manage requests:

    await Scope.friends.accept_request(request_id)
    await Scope.friends.decline_request(request_id)
    await Scope.friends.remove(friend_user_id)

An empty friends list is a successful 200 [] response.

## Messages

Send a message:

    var result: ScopeResponse = await Scope.messages.send(
        recipient_user_id,
        "Good luck!"
    )

The server takes the sender identity from the JWT. The client cannot impersonate another sender.

Message text must contain 1 to 2,000 characters.

Read conversation history:

    var result: ScopeResponse = await Scope.messages.list(
        other_user_id,
        50
    )

    if result.success:
        var messages: Array[ScopeMessage] = result.data

Both users must belong to the application.

## Notifications

Read notifications:

    var result: ScopeResponse = await Scope.notifications.list(
        true,
        50
    )

    if result.success:
        var notifications: Array[ScopeNotification] = result.data

Mark notifications read:

    await Scope.notifications.mark_read(notification_id)
    await Scope.notifications.mark_all_read()

An empty notification list is successful.

## Achievements

List achievements:

    var result: ScopeResponse = await Scope.achievements.list()

    if result.success:
        var achievements: Array[ScopeAchievement] = result.data

Read one achievement:

    var result: ScopeResponse = await Scope.achievements.get_achievement("first_bet")

Progress and unlock state are server-provided.

## Realtime

Realtime uses a WebSocket and must be polled from the game loop.

Connect after authentication:

    func connect_realtime() -> void:
        var result: ScopeResponse = Scope.realtime.connect_with_session(Scope.session)
        if not result.success:
            print(result.error)

Poll every frame:

    func _process(_delta: float) -> void:
        Scope.realtime.poll()

Subscribe:

    Scope.realtime.subscribe("presence")
    Scope.realtime.subscribe("leaderboard/gold")
    Scope.realtime.subscribe("player/%d" % Scope.current_user().id)

Publish a generic application event to a subscribed channel:

    Scope.realtime.publish("match/movement-test", {
        "position": {"x": 100.0, "y": 200.0},
        "timestamp": Time.get_unix_time_from_system()
    })

Publishing is intended for application gameplay events. The backend should
validate which channels and event types a client is allowed to publish. Do
not use it to bypass server authority for scores, currency, wagers, or other
protected state.

Receive messages:

    func _ready() -> void:
        Scope.realtime.message_received.connect(_on_realtime_message)

    func _on_realtime_message(message: Dictionary) -> void:
        print(message)

Presence messages look like:

    {
      "type": "presence",
      "channel": "presence",
      "data": {
        "user_id": 7,
        "online": true
      }
    }

Read online users over HTTP:

    var result: ScopeResponse = await Scope.realtime.online()
    var friends_result: ScopeResponse = await Scope.realtime.online_friends()

Close on logout:

    Scope.realtime.close()

Without poll(), WebSocket messages and connection state will not update.

## Storage

Upload:

    var result: ScopeResponse = await Scope.storage.upload(
        "user://screenshots/result.png",
        {"visibility": "application"}
    )

    if result.success:
        var file: ScopeStorageFile = result.data

Read file information:

    var result: ScopeResponse = await Scope.storage.info(file_id)

Download:

    var result: ScopeResponse = await Scope.storage.download(
        file_id,
        "user://downloads/result.png"
    )

To receive the raw file bytes instead of saving them directly:

    var result: ScopeResponse = await Scope.storage.download(file_id)
    if result.success:
        var bytes: PackedByteArray = result.data

Delete:

    await Scope.storage.delete(file_id)

## Analytics

Queue an event:

    Scope.analytics.track("menu_opened", {
        "screen": "main"
    })

Flush queued events:

    var result: ScopeResponse = await Scope.analytics.flush()

The SDK sends up to 100 queued events per flush.

## Recommended startup

Keep SDK setup in one startup script:

    extends Node

    func _ready() -> void:
        var result: ScopeResponse = await Scope.initialize()
        if not result.success:
            get_tree().change_scene_to_file("res://login.tscn")
            return

        if Scope.is_logged_in():
            get_tree().change_scene_to_file("res://game.tscn")
        else:
            get_tree().change_scene_to_file("res://login.tscn")

All game scenes should assume initialization has already completed.

## Recommended data organization

Use one document per game system instead of one large document:

    preferences
    audio_settings
    tutorial_progress
    cosmetic_loadout

This keeps updates small and prevents unrelated systems from overwriting one another.

Use server services for authoritative systems:

    Gold: Scope.wizards_wager.balance()
    Active wager: Scope.wizards_wager.current_bet()
    Bet result: Scope.wizards_wager.history()
    Other player profile: Scope.wizards_wager.player_profile(user_id)
    Leaderboard score submission: server-side only

## Common integration problems

### Scope autoload is missing

Enable the plugin or add the Scope autoload manually.

### Project settings are not visible

Settings are registered by the editor plugin. Enable the plugin and restart Godot if needed, then reopen Project Settings.

### Requests return 401 or 403

Check:

- The user is logged in.
- The application ID is correct.
- The public key is correct.
- The JWT is valid.
- The user belongs to the application.

### Godot reports Busy

Do not create another request service around the SDK HTTP service. Use the public SDK methods and await their responses. The SDK serializes requests through its internal HTTPRequest.

### A list is empty

Check result.success first. A successful empty list is normal:

    if result.success:
        var items: Array = result.data
        if items.is_empty():
            print("Nothing to show yet")

### A countdown drifts

Use the server's resolves_at timestamp and recalculate remaining time from the current time or server clock offset. Do not maintain the countdown by subtracting one from a cached integer.

### The client is submitting leaderboard scores

Remove that code. Score submission belongs in trusted backend logic. The client must never contain the service key used for score submission.

## Security summary

Safe to include in the client:

- API URL
- Application ID
- Public application key
- The user JWT managed by the SDK

Never include in the client:

- SCOPE_SERVICE_KEY
- Administrative credentials
- Job execution credentials
- Trusted leaderboard score-submission credentials

The client should request authoritative state from the server and display it. It should not calculate wager outcomes, treat local gold as authoritative, or submit arbitrary scores.
