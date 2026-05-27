## v2.0.1

- Renamed BepInEx plugin GUID from `com.github.tinyhoot.ShipLobby` to
  `stysk1.ShipLobby` to reflect the new fork maintainer. Players upgrading will
  get a fresh `stysk1.ShipLobby.cfg` config file with defaults.
- Synced the `BepInPlugin` `VERSION` constant with `manifest.json` (was stuck
  at `1.0.2`).

## v2.0.0

- Modernized build to target game v81 (81.0.5-ngd.0) with SDK-style project and GitHub Actions CI/CD.

## v1.0.2

- Fixes the ship lever getting stuck if someone joins before the post-mission
  stats screen has finished displaying.
- Fixes the `Invite Friends` button working during a mission.

## v1.0.1

- Fixes an issue where the game would hang after attempting to leave the planet
  if BepInEx's `HideManagerGameObject` was not set to `true`.

## v1.0.0

Initial release.