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
