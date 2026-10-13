#!/bin/bash
set -euo pipefail
package_root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
account=$(id -un)
export YNH_APP_BASEDIR="$package_root"
ynh_exec_as_app() { "$@"; }
# Privileged ownership changes are substituted; real modes and launchers run.
chown() {
  printf '%s\n' "$*" >> "$fixture/chown-calls"
  if [ "$(id -u)" -ne 0 ] && [[ "$*" == *root:* ]]; then return 0; fi
  command chown "$@"
}
ynh_app_setting_get() { return 0; }
ynh_app_config_run() { return 0; }
ynh_die() { return 1; }
source <(sed '\|^source /usr/share/yunohost/helpers$|d' "$package_root/scripts/_common.sh")
app=$account
install_dir="$fixture/runtime"
juliaup_depot="$install_dir/.julia"
juliaup_bin="$install_dir/.juliaup/bin/juliaup"
julia_bin="$install_dir/.juliaup/bin/julia"
julia_bin_dir="$install_dir/.juliaup/bin"
mkdir -p "$julia_bin_dir" "$juliaup_depot/juliaup" "$install_dir/registry_depot"
printf '{"Default":"release"}\n' > "$juliaup_depot/juliaup/juliaup.json"
printf private > "$install_dir/registry_depot/private"
chmod 600 "$install_dir/registry_depot/private"
cat > "$juliaup_bin" <<'FIXTURE'
#!/bin/bash
set -eu
runtime="${JULIAUP_DEPOT_PATH%/.julia}"
chmod 600 "$JULIAUP_DEPOT_PATH/juliaup/juliaup.json" "$runtime/.juliaup/bin/juliaup"
chmod 700 "$JULIAUP_DEPOT_PATH/juliaup"
if [ "${FIXTURE_FAIL:-0}" = 1 ]; then exit 17; fi
printf 'Default Channel Version\n * release 1.13.1\n'
FIXTURE
cp "$juliaup_bin" "$julia_bin"
chmod 600 "$juliaup_bin"
chmod 755 "$julia_bin"
assert_repaired() {
  test "$(stat -c %a "$juliaup_depot/juliaup/juliaup.json")" = 644
  test "$(stat -c %a "$juliaup_bin")" = 755
  test "$(stat -c %a "$juliaup_depot/juliaup")" = 1777
  test "$(stat -c %a "$juliaup_depot/juliaup/.juliaup-lock")" = 666
  test "$(stat -c %U "$juliaup_depot/juliaup/juliaup.json")" = "$account"
}
source <(sed '\|source .*_common.sh|d' "$package_root/scripts/config")
add_version=lts; remove_version=lts; default_version=release
for action in run__status run__add run__remove run__default run__update_versions run__update_juliaup run__update_environment; do
  "$action" >/dev/null
  assert_repaired
  rc=0
  FIXTURE_FAIL=1 "$action" >/dev/null || rc=$?
  test "$rc" = 17
  assert_repaired
done
_juliaup_status_list >/dev/null
assert_repaired
test "$(stat -c %a "$install_dir/registry_depot/private")" = 600

# The public CLI uses the same repair and retains the actual command's status.
sed -e "s|/usr/local/lib/julia_ynh/runtime-permissions.sh|$package_root/conf/runtime-permissions.sh|g" \
    -e "s|__INSTALL_DIR__|$install_dir|g" -e "s|__JULIAUP_DEPOT__|$juliaup_depot|g" \
    -e "s|__JULIAUP_BIN__|$juliaup_bin|g" -e "s|__APP__|$account|g" \
    "$package_root/conf/juliaup" > "$fixture/public-juliaup"
chmod 755 "$fixture/public-juliaup"
"$fixture/public-juliaup" update >/dev/null
assert_repaired
rc=0
FIXTURE_FAIL=1 "$fixture/public-juliaup" update >/dev/null || rc=$?
test "$rc" = 17
assert_repaired

# The dependency helper must never transfer Juliaup back to root. Paths and
# privileged group changes are confined to this fixture.
sed -e "s|/usr/local/lib/julia_ynh/runtime-permissions.sh|$package_root/conf/runtime-permissions.sh|g" \
    -e "s|/var/lib/julia julia|$install_dir $account|g" \
    -e "s|/var/lib/julia|$install_dir|g" -e "s|group=\"julia\"|group=\"$account\"|g" \
    -e '/^exit 0$/d' "$package_root/conf/julia-dependencies-permissions" > "$fixture/dependency-repair"
: > "$fixture/chown-calls"
source "$fixture/dependency-repair"
assert_repaired
if [ "$(id -u)" -ne 0 ] && grep -E 'root:.*[/]\.julia(up)?([ /]|$)' "$fixture/chown-calls" >/dev/null; then
  printf 'Runtime ownership was transferred to root\n' >&2; exit 1
fi

for consumer in "$@"; do
  consumer=$(cd "$consumer" && pwd)
  # Keep all paths inside the fixture, including the two writable depot layers.
  export YNH_APP_BASEDIR="$consumer"
  source <(sed '\|^source /usr/share/yunohost/helpers$|d' "$consumer/scripts/_common.sh")
  app=$account; app_home="$fixture/app"; install_dir="$fixture/app/project"
  data_dir="$fixture/app/data"; depot_dir="$fixture/app/cache"
  julia_home="$fixture/runtime"; julia_runtime_home="$julia_home"; julia_runtime_account=$account
  juliaup_home="$julia_home/.juliaup"; juliaup_depot="$julia_home/.julia"
  juliaup_bin="$juliaup_home/bin/juliaup"; julia_bin="$juliaup_home/bin/julia"
  julia_public_depot="$juliaup_depot"; shared_private_depot="$fixture/private-shared"
  shared_julia_owner="$account:$account"
  mkdir -p "$install_dir" "$data_dir" "$depot_dir" "$shared_private_depot"
  for failed in 0 1; do
    rc=0
    if [ -f "$consumer/conf/shared_julia_runtime.sh" ]; then
      FIXTURE_FAIL=$failed _pkg_exec fixture >/dev/null || rc=$?
    else
      FIXTURE_FAIL=$failed _pluto_update_deps >/dev/null || rc=$?
    fi
    test "$rc" = "$((failed*17))"
    assert_repaired
  done
done
printf 'PASS: config-panel actions, public Juliaup CLI and consumer Pkg success/failure repair permissions\n'
