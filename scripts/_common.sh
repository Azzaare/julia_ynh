#!/bin/bash
set -eu

# shellcheck disable=SC1091
source /usr/share/yunohost/helpers

app=${YNH_APP_INSTANCE_NAME:-julia}
install_dir="/var/lib/$app"
juliaup_depot="$install_dir/.julia"
juliaup_bin="$install_dir/.juliaup/bin/juliaup"
julia_bin="$install_dir/.juliaup/bin/julia"

_juliaup_exec() {
  ynh_exec_as_app "$juliaup_bin" "$@"
}

_juliaup_status_list() {
  local output lines
  output="$(_juliaup_exec status 2>/dev/null || true)"

  lines="$(echo "$output" | awk '
    /^[[:space:]]*Default[[:space:]]/ { next }
    /^[[:space:]]*-+[[:space:]]*$/ { next }
    /^[[:space:]]*$/ { next }
    {
      is_default = 0
      line = $0
      if (line ~ /^[[:space:]]*\*/) {
        is_default = 1
        sub(/^[[:space:]]*\*[[:space:]]+/, "", line)
      }
      sub(/^[[:space:]]+/, "", line)
      n = split(line, parts, /[[:space:]]+/)
      channel = parts[1]
      version = parts[2]
      if (channel == "" || version == "") next
      if (is_default) {
        print "- " channel ": " version " (default)"
      } else {
        print "- " channel ": " version
      }
    }
  ')"

  if [ -z "$lines" ]; then
    lines="- (no versions installed)"
  fi

  echo "|-"
  echo "$lines" | sed 's/^/  /'
}

_juliaup_install() {
  ynh_exec_as_app env JULIAUP_DEPOT_PATH="$juliaup_depot" bash -c \
    'curl -fsSL https://install.julialang.org | sh -s -- -y --add-to-path=no --background-selfupdate=0'
}

_julia_environment_update() {
  ynh_exec_as_app env \
    HOME="$install_dir" \
    JULIAUP_DEPOT_PATH="$juliaup_depot" \
    JULIA_DEPOT_PATH="$juliaup_depot" \
    "$julia_bin" --startup-file=no -e 'using Pkg; Pkg.update()'
}

ensure_juliaup_permissions() {
  # Ensure home and depot exist and are writable as expected.
  # Only the julia system user should own the shared depot. Other users
  # merely need read+execute access to the juliaup-managed binaries.
  mkdir -p "$install_dir" "$juliaup_depot/juliaup"
  chown -R "$app:$app" "$install_dir"

  chmod 755 "$install_dir"
  mkdir -p "$install_dir/.juliaup"
  find "$install_dir/.juliaup" -type d -exec chmod 755 {} \;
  chmod -R a+rX "$install_dir/.juliaup"

  chmod 755 "$juliaup_depot"
  find "$juliaup_depot/juliaup" -type d -exec chmod 755 {} \; 2>/dev/null || true
  chmod -R a+rX "$juliaup_depot/juliaup" 2>/dev/null || true

  # Global launcher for the primary instance
  if [ "$app" = "julia" ]; then
    cat > "/usr/local/bin/julia" << EOF
#!/bin/bash
set -eu
export JULIAUP_DEPOT_PATH="$juliaup_depot"
export JULIAUP_CHANNEL="\${JULIAUP_CHANNEL:-release}"
exec "$julia_bin" "\$@"
EOF
    chmod 755 "/usr/local/bin/julia"

    cat > "/usr/local/bin/juliaup" << EOF
#!/bin/bash
set -eu
cd "$install_dir"
export HOME="$install_dir"
export JULIAUP_DEPOT_PATH="$juliaup_depot"
export JULIA_DEPOT_PATH="$juliaup_depot"
exec "$juliaup_bin" "\$@"
EOF
    chmod 755 "/usr/local/bin/juliaup"
  fi
}
