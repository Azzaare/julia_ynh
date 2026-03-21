# Admin guide

## Global julia launcher

A global launcher is installed at /usr/local/bin/julia (primary instance only).
It runs Julia as the app system user and uses the juliaup depot in /home/julia/.julia.

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
