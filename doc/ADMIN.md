# Admin guide

## Global julia launcher

A global launcher is installed at /usr/local/bin/julia (primary instance only).
It uses the shared juliaup depot in /home/julia/.julia and runs the Julia binary
from /home/julia/.juliaup.

Notes:
- The juliaup CLI should be used via YunoHost actions or by running as the app user.
- The launcher is intended for system-wide Julia execution without extra setup.

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
