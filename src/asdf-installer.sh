#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------- #
#
# Install/Uninstall asdf plugins and versions from .tool-versions.
#
# "asdf-installer.sh --help" for more information.
#
# ---------------------------------------------- #

# ---------------------------------------------- #
#                      Utils                     #
# ---------------------------------------------- #

# Colors
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
normal="\e[0m"

function alert_die {
  local error="${1}"

  print_new_line
  alert "Error: $error"
  die
}

function print {
  echo -e "${*}"
}

function print_error {
  print >&2 "${*}"
}

function print_new_line {
  print ""
}

# Prints a green success message.
function success {
  print "${green}${*}${normal}"
}

# Prints a yellow warning message.
function warning {
  print "${yellow}${*}${normal}"
}

# Prints a red error message.
function alert {
  print_error "${red}${*}${normal}"
}

# Wrapper for "exit" when error.
function die {
  exit 1
}

# ---------------------------------------------- #
#               Install / Uninstall              #
# ---------------------------------------------- #

function help {
  cat <<EOF

Install/Uninstall asdf plugins and versions from .tool-versions.

Syntax:
  $0 install [local|global|shell]     Install plugins and versions from .tool-versions
  $0 uninstall [versions|plugins]     Uninstall plugins and versions from .tool-versions

Options:
  -h, --help:     Show this message"

EOF
}

function is_plugin_installed {
  local all_plugins=${1}
  local plugin=${2}

  print "${all_plugins}" | grep -Fxq "${plugin}" >/dev/null 2>&1
}

function is_version_installed {
  local plugin=${1}
  local version=${2}

  asdf where "${plugin}" "${version}" |
    grep -vFxq "Version not installed" >/dev/null 2>&1
}

function plugin_from_line {
  local line=${1}

  print "${line}" | cut -d " " -f1
}

function version_from_line {
  local line=${1}

  print "${line}" | cut -d " " -f2
}

function uncommented_lines {
  grep -v "^ *#" <".tool-versions"
}

function install {
  local all_plugins
  set +e
  all_plugins=$(asdf plugin list)
  set -e

  uncommented_lines | while IFS= read -r line; do
    local plugin
    local version
    plugin=$(plugin_from_line "${line}")
    version=$(version_from_line "${line}")

    if ! is_plugin_installed "${all_plugins}" "${plugin}"; then
      asdf plugin add "${plugin}"
    fi

    asdf install "${plugin}" "${version}"
    asdf "${scope}" "${plugin}" "${version}"
  done

  success "✓ asdf plugins and versions installed"
}

function uninstall_versions {
  uncommented_lines | while IFS= read -r line; do
    local plugin
    local version
    plugin=$(plugin_from_line "${line}")
    version=$(version_from_line "${line}")

    if is_version_installed "${plugin}" "${version}"; then
      print "remove ${plugin} ${version}"
      asdf uninstall "${plugin}" "${version}"
    fi
  done

  success "✓ asdf versions uninstalled"
}

function uninstall_plugins {
  local all_plugins
  set +e
  all_plugins=$(asdf plugin list)
  set -e

  uncommented_lines | while IFS= read -r line; do
    local plugin
    plugin=$(plugin_from_line "${line}")

    if is_plugin_installed "${all_plugins}" "${plugin}"; then
      print "remove ${plugin}"
      asdf plugin remove "${plugin}"
    fi
  done

  success "✓ asdf plugins uninstalled"
}

function is_valid_install_scope {
  local scope=${1}
  local scopes="local global shell"

  print "${scopes}" | grep -qw "${scope}"
}

function is_valid_uninstall_mode {
  local mode=${1}
  local modes="versions plugins"

  print "${modes}" | grep -qw "${mode}"
}

function validate_install_scope {
  local scope=${1}

  if [[ -z ${scope} ]]; then
    alert_die "Install scope is required"
  fi

  if ! is_valid_install_scope "${scope}"; then
    alert_die "Unknown install scope"
  fi
}

function validate_uninstall_mode {
  local mode=${1}

  if [[ -z ${mode} ]]; then
    alert_die "Uninstall mode is required"
  fi

  if ! is_valid_uninstall_mode "${mode}"; then
    alert_die "Unknown uninstall mode"
  fi
}

function parse_options {
  for opt in "${@}"; do
    case ${opt} in
    -h | --help)
      help
      close
      ;;

    --* | -*)
      alert "Error: Unknown option ${opt}"
      help
      die
      ;;
    esac
  done
}

function apply_command {
  if [ -n "${1}" ]; then
    local command=${1}
  else
    help
    die
  fi

  for opt in ${command}; do
    case ${opt} in
    install)

      local scope="${2}"
      validate_install_scope "${scope}"
      install
      ;;

    uninstall)

      local mode="${2}"
      validate_uninstall_mode "${mode}"
      uninstall_"${mode}"

      ;;

    *)
      alert "Error: Unknown command ${opt}"
      help
      die
      ;;
    esac
  done
}

parse_options "${@}"
apply_command "${@}"
