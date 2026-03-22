# Admin guide

## Global julia launcher

A global launcher is installed at /usr/local/bin/julia (primary instance only).
It uses the shared juliaup depot in /var/lib/julia/.julia and runs the Julia binary
from /var/lib/julia/.juliaup.
The launcher also forces HOME=/var/lib/julia to avoid failures for users without
a home directory.
It also changes the working directory to /var/lib/julia to avoid errors when the
current directory does not exist for the caller.

Notes:
- Prefer the webadmin Config panel for juliaup management.
- This is a global Julia installation managed by juliaup. It is sufficient for
  other YunoHost apps or services that depend on Julia: they can call the global
  `julia` launcher and rely on juliaup for versions and environments.
- The launcher is intended for system-wide Julia execution without extra setup.
- This package is single-instance by design (shared juliaup depot/launcher).

## Global juliaup launcher

A global launcher is installed at /usr/local/bin/juliaup (primary instance only).
It runs with HOME=/var/lib/julia and uses the shared juliaup depot.

## Webadmin actions

In YunoHost webadmin, use the app "Config panel" to access juliaup actions
(status, add/remove versions, set default, update).

## CLI (optional)

If you still want to manage versions from the shell, use the global launcher:

- List installed versions: `juliaup status`
- Install LTS: `juliaup add lts`
- Install a specific version: `juliaup add 1.11`
- Set default version: `juliaup default 1.11`
- Update installed versions: `juliaup update`
- Update juliaup: `juliaup self update`
- Remove a version: `juliaup remove 1.10`
