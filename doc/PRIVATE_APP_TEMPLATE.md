# Private Julia App Packaging Pattern

This note documents the packaging pattern used for private Julia apps that
depend on `julia_ynh`, without exposing private registry access to unrelated
apps.

## Goals

- Keep Julia itself installed globally through `julia_ynh`.
- Let every Julia-based app use the same global runtime.
- Allow public apps such as Pluto to reuse a shared public Julia depot.
- Allow private apps to reuse a shared private depot limited to apps that need
  the same private registry access.
- Keep application runtime simple and robust: the app reads packages at
  runtime, but package updates happen only through admin actions.

## Recommended Depot Layout

Use three layers:

1. Global Julia runtime
   binaries in `/var/lib/julia/.juliaup`

2. Shared depots
   Public shared depot:
   `/var/lib/julia/.julia`

   Private shared depot for one access class:
   `/var/lib/julia/<app_or_group>_shared_depot`

3. Per-instance writable overlay
   `/var/lib/__APP__/julia_depot`

## Runtime Model

At runtime, the app should use:

```bash
JULIAUP_DEPOT_PATH=/var/lib/julia/.julia
JULIA_DEPOT_PATH=/var/lib/__APP__/julia_depot:/var/lib/julia/<shared_depot>
```

This gives the app:

- a local writable overlay for logs, caches, scratch spaces, and any leftover
  per-instance precompilation artifacts
- read access to the shared depot containing packages, registries, artifacts,
  and common precompile results

## Update Model

Do not let the runtime service fetch private packages.

Instead, package updates should happen only during:

- `install`
- `upgrade`
- config-panel actions such as `Update Julia environment`

For private apps, these admin-time `Pkg` operations should run as `root`,
using the SSH key already stored in `/root/.ssh/...`.

For example:

```bash
env \
  HOME=/root \
  JULIAUP_DEPOT_PATH=/var/lib/julia/.julia \
  JULIA_DEPOT_PATH=/var/lib/julia/<private_shared_depot>:/var/lib/__APP__/julia_depot \
  JULIA_PKG_USE_CLI_GIT=true \
  GIT_SSH_COMMAND='ssh -i /root/.ssh/<deploy_key> -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new' \
  /usr/local/bin/julia --project=/var/www/__APP__ --startup-file=no -e 'using Pkg; Pkg.Registry.update(); Pkg.update(); Pkg.precompile()'
```

## Why Not a Single Global Writable Depot?

Because it creates ownership and locking conflicts:

- multiple app users touch the same Git registries
- `LibGit2` complains about owner mismatches
- one app can accidentally expose a private registry to another
- update actions become brittle

The mixed model avoids these problems while still sharing most heavy assets.

## Public App Template

For a public app from `General`:

- shared depot:
  `/var/lib/julia/.julia`
- local overlay:
  `/var/lib/__APP__/julia_depot`
- runtime path:
  `local_overlay:public_shared`
- install/upgrade path:
  `public_shared:local_overlay`

## Private App Template

For a private app using a private registry:

- shared private depot:
  `/var/lib/julia/<private_group>_shared_depot`
- local overlay:
  `/var/lib/__APP__/julia_depot`
- runtime path:
  `local_overlay:private_shared`
- install/upgrade path:
  `private_shared:local_overlay`
- private registry access:
  root-only via `GIT_SSH_COMMAND`

## Practical Rules

- `julia_ynh` should expose the global Julia runtime, not force all users into a
  single writable depot.
- Public apps should never see private shared depots in `JULIA_DEPOT_PATH`.
- Private registry credentials should stay in `root`.
- Runtime services should not need Git access.
- Config-panel update actions should be safe to run repeatedly.

## Minimal Checklist

- One global Julia runtime from `julia_ynh`
- One writable local depot per instance
- Shared depot read-only at runtime
- Package updates only in admin contexts
- Private registry accessed only by admin-time scripts
- Systemd service using a runtime-oriented `JULIA_DEPOT_PATH`
