#!/bin/sh
# Shared by Julia's lifecycle, config-panel actions and public Juliaup wrapper.
# Call only with the trusted runtime home and its dedicated system account.
repair_shared_julia_runtime_permissions() {
  runtime_home=$1
  runtime_account=$2
  mkdir -p "$runtime_home/.juliaup" "$runtime_home/.julia/juliaup" "$runtime_home/.julia/logs"
  chown "$runtime_account:$runtime_account" "$runtime_home"
  chown -R "$runtime_account:$runtime_account" "$runtime_home/.juliaup" "$runtime_home/.julia"
  chmod 755 "$runtime_home"
  find "$runtime_home/.juliaup" "$runtime_home/.julia" -type d -exec chmod 755 {} +
  chmod -R a+rX,go-w "$runtime_home/.juliaup" "$runtime_home/.julia"
  if [ -d "$runtime_home/.juliaup/bin" ]; then
    find "$runtime_home/.juliaup/bin" -type f -exec chmod u+rwx,go+rx,go-w {} +
  fi
  touch "$runtime_home/.julia/juliaup/.juliaup-lock"
  chown "$runtime_account:$runtime_account" "$runtime_home/.julia/juliaup/.juliaup-lock"
  chmod 1777 "$runtime_home/.julia/juliaup" "$runtime_home/.julia/logs"
  chmod 666 "$runtime_home/.julia/juliaup/.juliaup-lock"
}
