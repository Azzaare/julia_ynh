if [ "${USER:-}" = "__APP__" ]; then
  export PATH="__INSTALL_DIR__/.juliaup/bin:$PATH"
fi
