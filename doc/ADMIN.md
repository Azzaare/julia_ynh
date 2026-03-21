# Admin guide

## Global julia launcher

A global launcher is installed at /usr/local/bin/julia (primary instance only).
It uses the shared juliaup depot in /home/julia/.julia and runs the Julia binary
from /home/julia/.juliaup.
The launcher also forces HOME=/home/julia to avoid failures for users without
a home directory.
It also changes the working directory to /home/julia to avoid errors when the
current directory does not exist for the caller.

Notes:
- The juliaup CLI should be used via YunoHost actions or by running as the app user.
- The launcher is intended for system-wide Julia execution without extra setup.
- This package is single-instance by design (shared juliaup depot/launcher).

## Webadmin actions

In YunoHost webadmin, use the app "Config panel" to access juliaup actions
(status, add/remove versions, set default, update).

## List installed Julia versions

juliaup status

## Install LTS

juliaup add lts

## Install a specific version

juliaup add 1.11

## Set default Julia version

juliaup default 1.11

## Update installed Julia versions

juliaup update

## Update juliaup

juliaup self update

## Remove a version

juliaup remove 1.10
