#!/bin/bash
set -eu

# shellcheck disable=SC1091
source /usr/share/yunohost/helpers

app=${YNH_APP_INSTANCE_NAME:-julia}
install_dir="/home/$app"
juliaup_depot="/home/$app/.julia"
juliaup_bin="/home/$app/.juliaup/bin/juliaup"
julia_bin="/home/$app/.juliaup/bin/julia"

ensure_juliaup_permissions() {
  # Ensure home and depot exist and are writable as expected
  mkdir -p "/home/$app" "$juliaup_depot/juliaup"
  chown -R "$app:$app" "/home/$app"

  chmod 755 "/home/$app"
  chmod -R o+rx "/home/$app/.juliaup"
  chmod -R o+rx "$juliaup_depot"

  # Allow all users to create juliaup lockfiles (needed by the julia launcher)
  chmod 1777 "$juliaup_depot"
  chmod 1777 "$juliaup_depot/juliaup"
  touch "$juliaup_depot/juliaup/.juliaup-lock"
  chmod 666 "$juliaup_depot/juliaup/.juliaup-lock"

  # Global launcher for the primary instance
  if [ "$app" = "julia" ]; then
    cat > "/usr/local/bin/julia" << EOF
#!/bin/bash
set -eu
umask 000
cd "/home/$app"
export HOME="/home/$app"
export JULIAUP_DEPOT_PATH="/home/$app/.julia"
export JULIA_DEPOT_PATH="/home/$app/.julia"
export JULIAUP_CHANNEL="\${JULIAUP_CHANNEL:-release}"
exec "/home/$app/.juliaup/bin/julia" "\$@"
EOF
    chmod 755 "/usr/local/bin/julia"
  fi
}
