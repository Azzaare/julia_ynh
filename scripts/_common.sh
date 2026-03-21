#!/bin/bash
set -eu

# shellcheck disable=SC1091
source /usr/share/yunohost/helpers

app=${YNH_APP_INSTANCE_NAME:-julia}
install_dir="/home/$app"
