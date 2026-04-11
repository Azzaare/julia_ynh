#!/bin/bash
set -eu

# shellcheck disable=SC1091
source /usr/share/yunohost/helpers

app=${YNH_APP_INSTANCE_NAME:-julia}
install_dir="/var/lib/$app"
juliaup_depot="$install_dir/.julia"
juliaup_bin="$install_dir/.juliaup/bin/juliaup"
julia_bin="$install_dir/.juliaup/bin/julia"
julia_bin_dir="$install_dir/.juliaup/bin"

_exec_in_shared_julia_home() {
  ynh_exec_as_app env \
    HOME="$install_dir" \
    JULIAUP_DEPOT_PATH="$juliaup_depot" \
    JULIA_DEPOT_PATH="$juliaup_depot" \
    PATH="$julia_bin_dir:$PATH" \
    bash -c 'cd "$1"; shift; exec "$@"' bash "$install_dir" "$@"
}

_juliaup_exec() {
  _exec_in_shared_julia_home "$juliaup_bin" "$@"
}

_julia_exec() {
  _exec_in_shared_julia_home "$julia_bin" "$@"
}

_run_with_permissions_repair() {
  local rc=0

  "$@" || rc=$?
  ensure_juliaup_permissions

  return "$rc"
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
  _exec_in_shared_julia_home bash -c \
    'curl -fsSL https://install.julialang.org | sh -s -- -y --add-to-path=no --background-selfupdate=0'
}

_julia_environment_update() {
  _julia_exec --startup-file=no -e 'using Pkg; registry_dir = joinpath(first(Base.DEPOT_PATH), "registries", "General"); isdir(registry_dir) || Pkg.Registry.add("General"); Pkg.Registry.update(); Pkg.update(); Pkg.precompile()'
}

ensure_juliaup_permissions() {
  # Keep the shared depot readable for runtime users, but writable only
  # by the dedicated julia system user, except for the juliaup lockfile
  # directory and lockfile which must stay writable for launcher users.
  mkdir -p "$install_dir" "$install_dir/.juliaup" "$juliaup_depot" "$juliaup_depot/juliaup" "$juliaup_depot/logs"
  chown -R "$app:$app" "$install_dir"

  chmod 755 "$install_dir"
  find "$install_dir/.juliaup" -type d -exec chmod 755 {} \; 2>/dev/null || true
  chmod -R a+rX "$install_dir/.juliaup" 2>/dev/null || true
  chmod -R go-w "$install_dir/.juliaup" 2>/dev/null || true

  find "$juliaup_depot" -type d -exec chmod 755 {} \; 2>/dev/null || true
  chmod -R a+rX "$juliaup_depot" 2>/dev/null || true
  chmod -R go-w "$juliaup_depot" 2>/dev/null || true
  # The launcher creates a lockfile next to juliaup.json before reading it.
  touch "$juliaup_depot/juliaup/.juliaup-lock"
  chown "$app:$app" "$juliaup_depot/juliaup/.juliaup-lock"
  chmod 1777 "$juliaup_depot/juliaup"
  chmod 666 "$juliaup_depot/juliaup/.juliaup-lock"
  chmod 1777 "$juliaup_depot/logs"
}

deploy_julia_shell_files() {
  ynh_config_add --template="profile.sh" --destination="/etc/profile.d/$app.sh"
  chmod 644 "/etc/profile.d/$app.sh"

  if [ "$app" = "julia" ]; then
    ynh_config_add --template="julia" --destination="/usr/local/bin/julia"
    chmod 755 "/usr/local/bin/julia"

    ynh_config_add --template="juliaup" --destination="/usr/local/bin/juliaup"
    chmod 755 "/usr/local/bin/juliaup"
  fi
}
