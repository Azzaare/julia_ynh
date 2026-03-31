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
  # Ensure home and depot exist and are writable as expected
  mkdir -p "$install_dir" "$juliaup_depot/juliaup"
  chown -R "$app:$app" "$install_dir"

  chmod 755 "$install_dir"
  chmod -R o+rx "$install_dir/.juliaup"
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
cd "$install_dir"
export HOME="$install_dir"
export JULIAUP_DEPOT_PATH="$juliaup_depot"
export JULIA_DEPOT_PATH="$juliaup_depot"
export JULIAUP_CHANNEL="\${JULIAUP_CHANNEL:-release}"
exec "$julia_bin" "\$@"
EOF
    chmod 755 "/usr/local/bin/julia"

    cat > "/usr/local/bin/juliaup" << EOF
#!/bin/bash
set -eu
umask 000
cd "$install_dir"
export HOME="$install_dir"
export JULIAUP_DEPOT_PATH="$juliaup_depot"
export JULIA_DEPOT_PATH="$juliaup_depot"
exec "$juliaup_bin" "\$@"
EOF
    chmod 755 "/usr/local/bin/juliaup"
  fi
}
