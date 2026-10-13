# Julia (via juliaup) - YunoHost package

This app installs the Julia programming language using juliaup and exposes Julia version management through the YunoHost webadmin config panel.

It installs only Julia and juliaup. Julia packages such as Pluto.jl, Oxygen.jl, IJulia, etc. are intentionally out of scope and should be handled by separate apps.

## Installation

From the repository root:

yunohost app install ./

Or from a local path:

yunohost app install /path/to/julia_ynh

## Admin usage examples

List installed versions:

juliaup status

Install LTS:

juliaup add lts

Install a specific version:

juliaup add 1.11

Set default version:

juliaup default 1.11

Update installed versions:

juliaup update

Update juliaup:

juliaup self update

Remove a version:

juliaup remove 1.10

Shared-runtime permissions are repaired before and after every Juliaup command,
including status, config-panel actions, the public CLI and failed commands. The
same routine is installed read-only in `/usr/local/lib/julia_ynh/` for consumers.
Juliaup remains owned by the `julia` account; dependency maintenance must not
transfer its configuration or binaries to root. Private registry depots retain
separate access rules. Application package operations repair permissions on exit.

Run `bash tests/permissions.sh ../pluto_ynh ../caravane_ynh` to exercise the real
file modes with substituted administrative identities and local command peers.
This checks successful and failed actions without downloading Julia or packages.
