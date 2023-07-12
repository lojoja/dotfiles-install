#!/bin/zsh
#
# Uninstall dotfiles

LOCAL_PATH="$HOME/.local"
BIN_PATH="${LOCAL_PATH}/bin"
OPT_PATH="${LOCAL_PATH}/opt"

DOTFILES_PATH="${OPT_PATH}/dotfiles" # The dotfiles install path
DOTFILES_COMMAND="${DOTFILES_PATH}/bin/dotfiles"
DOTFILES_COMMAND_TARGET="${BIN_PATH}/dotfiles"

##########
# Output #
##########

typeset -A STYLES=(
  'reset' $(tput sgr0)
  'bold' $(tput bold)
  'red' $(tput setaf 1)
  'green' $(tput setaf 2)
  'blue' $(tput setaf 4)
)

# Print a stylized message prefixed with "Error: ".
#
# $1 - The message to print. Default is "Undefined".
function error() {
  print >&2
  print "$STYLES[red]$STYLES[bold]Error:$STYLES[reset] ${1:-"Undefined"}" >&2
}

# Print a stylized unprefixed message.
#
# $1 - The message to print. Default is "Undefined".
function info() {
  print >&2
  print "$STYLES[blue]$STYLES[bold]${1:-"Undefined"}$STYLES[reset]" >&2
}

# Print a stylized message prefixed with "OK: ".
#
# $1 - The message to print. Default is "Undefined".
function ok() {
  print "$STYLES[green]$STYLES[bold]OK:$STYLES[reset] ${1:-"Undefined"}" >&2
}

##########################
# Flow Control Functions #
##########################

# Stop execution with a relevant error message.
#
# $1 - The message to print. Default is "Undefined".
function die() {
  error "${1:-"Undefined"}"
  exit 1
}

#######################
# Uninstall Functions #
#######################

# Verify dotfiles is installed or die.
function dotfilesIsInstalled() {
  info 'Checking for dotfiles installation'

  if ! [[ -f $DOTFILES_COMMAND || -d $DOTFILES_PATH ]]
  then
    die 'dotfiles is not installed'
  fi

  ok 'dotfiles is installed'
}

# Uninstall dotfiles.
function uninstallDotfiles() {
  info 'Uninstalling dotfiles'

  if [[ -f $DOTFILES_COMMAND_TARGET ]]
  then
    if rm -f "$DOTFILES_COMMAND_TARGET" &>/dev/null
    then
      ok 'dotfiles command unlinked'
    else
      die 'Failed to unlink dotfiles command'
    fi
  fi

  if ! $DOTFILES_COMMAND uninstall
  then
    die 'Failed to uninstall dotfiles'
  fi

  if ! rm -rf "$DOTFILES_PATH" &>/dev/null
  then
    die 'Failed to remove dotfiles repository'
  fi
}

# Main uninstall routine.
function main() {
  info 'dotfiles uninstall started'

  dotfilesIsInstalled
  uninstallDotfiles

  info 'dotfiles uninstall complete. Restart terminal to deactivate.'
}

################################################################################

main
