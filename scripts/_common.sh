#!/bin/bash
set -eu

# shellcheck disable=SC1091
source /usr/share/yunohost/helpers
source "$YNH_APP_BASEDIR/conf/runtime-permissions.sh"

app=${YNH_APP_INSTANCE_NAME:-julia}
install_dir="/var/lib/$app"
juliaup_depot="$install_dir/.julia"
juliaup_bin="$install_dir/.juliaup/bin/juliaup"
julia_bin="$install_dir/.juliaup/bin/julia"
julia_bin_dir="$install_dir/.juliaup/bin"
registry_depot="$install_dir/registry_depot"
julia_dependencies_group="julia"

_exec_in_shared_julia_home() {
  ynh_exec_as_app env \
    HOME="$install_dir" \
    JULIAUP_DEPOT_PATH="$juliaup_depot" \
    JULIA_DEPOT_PATH="$juliaup_depot" \
    PATH="$julia_bin_dir:$PATH" \
    bash -c 'cd "$1"; shift; exec "$@"' bash "$install_dir" "$@"
}

_juliaup_exec() {
  _run_with_permissions_repair _exec_in_shared_julia_home "$juliaup_bin" "$@"
}

_julia_exec() {
  _run_with_permissions_repair _exec_in_shared_julia_home "$julia_bin" "$@"
}

_exec_in_shared_registry_depot() {
  local -a registry_environment=(
    "HOME=$install_dir"
    "JULIAUP_DEPOT_PATH=$juliaup_depot"
    "JULIA_DEPOT_PATH=$registry_depot"
    "PATH=$julia_bin_dir:$PATH"
  )

  if [ -n "${oasis_registry_token:-}" ]; then
    registry_environment+=(
      "GIT_CONFIG_GLOBAL=$install_dir/.oasis-registry-gitconfig"
      "OASIS_REGISTRY_URL=https://gitlab.naze.baffier.fr/julia/Oasis.git"
    )
  fi

  ynh_exec_as_app env \
    "${registry_environment[@]}" \
    bash -c 'cd "$1"; shift; exec "$@"' bash "$install_dir" "$@"
}

_run_with_permissions_repair() {
  local rc=0

  # An upgrade may start from metadata created by an older package revision.
  # Repair it before invoking juliaup, not only after a failed invocation.
  if [ -e "$juliaup_bin" ]; then
    repair_shared_julia_runtime_permissions "$install_dir" "$app" || return
  fi
  "$@" || rc=$?
  repair_shared_julia_runtime_permissions "$install_dir" "$app" || return

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
  # Do not use `curl | sh`: a failed network transfer otherwise loses the
  # downloader's status and leaves the YunoHost operation with no diagnosis.
  # Keeping the bootstrap script on disk makes the failure atomic and lets
  # curl retry transient network interruptions before Juliaup is invoked.
  _exec_in_shared_julia_home bash -c '
    set -eu
    installer="$(mktemp)"
    trap "rm -f \"$installer\"" EXIT
    curl --fail --show-error --location --retry 5 --retry-all-errors \
      --connect-timeout 30 --output "$installer" https://install.julialang.org
    sh "$installer" -y --add-to-path=no --background-selfupdate=0
  '
}

_ensure_default_julia_channel() {
  if [ ! -x "$julia_bin" ]; then
    _juliaup_exec add release
    _juliaup_exec default release
  fi

  # With --add-to-path=no, recent Juliaup installers do not always create the
  # conventional `julia` launcher.  Keep a stable private entry point for the
  # shared runtime and dependent packages, while leaving channel selection to
  # Juliaup itself.
  if [ ! -x "$julia_bin" ]; then
    rm -f "$julia_bin"
    cat > "$julia_bin" <<EOF
#!/bin/sh
exec "$juliaup_bin" run release "\$@"
EOF
    chmod 755 "$julia_bin"
  fi
}

_julia_environment_update() {
  # Registry-depot ownership is handled separately from runtime permissions.
  _julia_exec --startup-file=no -e 'println(VERSION)'
}

_bootstrap_shared_registries() {
  local credentials_file="$install_dir/.oasis-registry-git-credentials"
  local gitconfig_file="$install_dir/.oasis-registry-gitconfig"
  local rc=0
  local xtrace_enabled=0

  # Julia compiles Pkg while adding registries.  The bootstrap must therefore
  # own this depot before the final shared read-only permissions are applied.
  mkdir -p "$registry_depot"
  chown -R "$app:$app" "$registry_depot"

  if [ -n "${oasis_registry_token:-}" ]; then
    case "$-" in
      *x*)
        xtrace_enabled=1
        set +x
        ;;
    esac
    umask 077
    printf "https://oauth2:%s@gitlab.naze.baffier.fr\n" "$oasis_registry_token" > "$credentials_file"
    printf "[credential]\n\thelper = store --file %s\n" "$credentials_file" > "$gitconfig_file"
    chown "$app:$app" "$credentials_file" "$gitconfig_file"
    if [ "$xtrace_enabled" -eq 1 ]; then
      set -x
    fi
  fi

  _run_with_permissions_repair _exec_in_shared_registry_depot "$julia_bin" --startup-file=no -e '
    using Pkg
    specs = Pkg.RegistrySpec[
      Pkg.RegistrySpec(name="General"),
      Pkg.RegistrySpec(url="https://github.com/Mirage-Interactive-Fr/Mirage.git"),
    ]
    oasis_registry_url = get(ENV, "OASIS_REGISTRY_URL", "")
    isempty(oasis_registry_url) || push!(specs, Pkg.RegistrySpec(url=oasis_registry_url))
    for spec in specs
      try
        Pkg.Registry.add(spec)
      catch err
        msg = lowercase(sprint(showerror, err))
        occursin("already exists", msg) || rethrow(err)
      end
    end
    Pkg.Registry.update()
  ' || rc=$?

  rm -f "$credentials_file" "$gitconfig_file"
  return "$rc"
}

ensure_juliaup_permissions() {
  repair_shared_julia_runtime_permissions "$install_dir" "$app"

  getent group "$julia_dependencies_group" >/dev/null 2>&1 || groupadd --system "$julia_dependencies_group"
  usermod --append --groups "$julia_dependencies_group" "$app"
  for shared_path in \
    "$install_dir/registry_depot" \
    "$install_dir/registry_sources" \
    "$install_dir/julia_shared_depot"
  do
    [ -e "$shared_path" ] || continue
    chown -R root:"$julia_dependencies_group" "$shared_path"
    chmod -R g+rX "$shared_path" 2>/dev/null || true
    chmod -R go-w "$shared_path" 2>/dev/null || true
  done
}

deploy_julia_shell_files() {
  install -d -m 755 /usr/local/lib/julia_ynh
  ynh_config_add --template="runtime-permissions.sh" --destination="/usr/local/lib/julia_ynh/runtime-permissions.sh"
  chown root:root /usr/local/lib/julia_ynh/runtime-permissions.sh
  chmod 644 /usr/local/lib/julia_ynh/runtime-permissions.sh
  ynh_config_add --template="profile.sh" --destination="/etc/profile.d/$app.sh"
  chmod 644 "/etc/profile.d/$app.sh"

  if [ "$app" = "julia" ]; then
    ynh_config_add --template="julia" --destination="/usr/local/bin/julia"
    chmod 755 "/usr/local/bin/julia"

    ynh_config_add --template="juliaup" --destination="/usr/local/bin/juliaup"
    chmod 755 "/usr/local/bin/juliaup"
  fi

  ynh_config_add --template="julia-dependencies-permissions" --destination="/usr/local/sbin/julia-dependencies-permissions"
  chmod 755 "/usr/local/sbin/julia-dependencies-permissions"
}
