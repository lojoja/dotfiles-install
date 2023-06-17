#!/bin/zsh
#
# Initialize system and install dotfiles

BIN_PATH=/usr/local/bin
OPT_PATH=/usr/local/opt
BASE_PATH="${OPT_PATH}/lojoja" # The base path for lojoja project installations

DEPENDENCIES=('brew' 'port' 'git' 'zsh')

DOTFILES_REPOSITORY=https://github.com/lojoja/dotfiles
DOTFILES_DEPENDENCIES=('python311' 'py311-pip' 'ansible') # Dotfiles dependencies are port names
DOTFILES_PATH="${BASE_PATH}/dotfiles" # The dotfiles install path
DOTFILES_COMMAND="${DOTFILES_PATH}/bin/dotfiles"
DOTFILES_COMMAND_TARGET="${BIN_PATH}/dotfiles"

typeset -A STYLES=(
  'reset' $(tput sgr0)
  'bold' $(tput bold)
  'red' $(tput setaf 1)
  'green' $(tput setaf 2)
  'yellow' $(tput setaf 3)
  'blue' $(tput setaf 4)
  'magenta' $(tput setaf 5)
)

#####################
# Utility Functions #
#####################

# Print a message prefixed with "Error: " and stop execution.
#
# $1 - The message to print
function die() {
  print >&2
  print "$STYLES[red]$STYLES[bold]Error:$STYLES[reset] ${1:-'Undefined'}" >&2
  exit 1
}

# Print an unprefixed message.
#
# $1 - The message to print
function info() {
  print >&2
  print "$STYLES[blue]$STYLES[bold]${1:-'Undefined'}$STYLES[reset]" >&2
}

# Print a message prefixed with "OK: ".
#
# $1 - The message to print
function ok() {
  print "${STYLES[green]}$STYLES[bold]OK:$STYLES[reset] ${1:-'Undefined'}" >&2
}

# Print a message prefixed with "Warning: ".
#
# $1 - The message to print
function warn() {
  print "${STYLES[yellow]}$STYLES[bold]OK:$STYLES[reset] ${1:-'Undefined'}" >&2
}

# Prompt for sudo password. Password is printed to be captured by caller.
function getSudoPassword() {
  local sudoPassword

  while true
  do
    read -s "sudoPassword?$STYLES[magenta]$STYLES[bold]Enter sudo password:$STYLES[reset] "
    [[ $sudoPassword != $'\n' && $sudoPassword != $'\r' ]] && print >&2
    [[ $sudoPassword == *[![:space:]]* ]] && break

    warn 'Sudo password cannot be blank'
  done

  print -n "$sudoPassword"
}

# Refresh the sudo session or die if password is invalid.
#
# $1 - The sudo password
function refreshSudo() {
  if ! sudo -vp '' -S <<< "$1" &>/dev/null
  then
    die 'Invalid sudo password'
  fi
}

##########################
# Installation Functions #
##########################

# Verify all installation dependencies are satisifed or die.
function checkInstallationDependencies() {
  local dependency

  info 'Checking installation dependencies'

  for dependency in $DEPENDENCIES; do
    if ! command -v "$dependency" &>/dev/null
    then
      die "Failed to find $dependency dependency"
    fi

    ok "$dependency is available"
  done
}

# Verify dotfiles is not installed or die.
function dotfilesIsNotInstalled() {
  info 'Checking for existing dotfiles installation'

  if [[ -f $DOTFILES_COMMAND_TARGET || -d $DOTFILES_PATH ]]
  then
    die 'dotfiles is already installed'
  fi

  ok 'dotfiles is not installed'
}

# Install dotfiles dependencies or die.
function installDependencies() {
  local dependency

  info 'Installing dotfiles dependencies'

  for dependency in $DOTFILES_DEPENDENCIES; do
    if ! sudo port -N install $dependency
    then
      die "Failed to install $dependency"
    fi

    ok "$dependency installed"
  done
}

# Install dotfiles.
function installDotfiles() {
  info 'Installing dotfiles'

  if mkdir -p "$BASE_PATH" &>/dev/null
  then
    ok 'Base path exists'
  else
    die 'Failed to create base path'
  fi

  if git clone "$DOTFILES_REPOSITORY" "$DOTFILES_PATH" &>/dev/null
  then
    ok 'Cloned dotfiles repository'
  else
    revertInstall 'Failed to clone dotfiles repository'
  fi

  if ln -s "$DOTFILES_COMMAND" "$DOTFILES_COMMAND_TARGET" &>/dev/null
  then
    ok 'Linked dotfiles command'
  else
    revertInstall 'Failed to link dotfiles command'
  fi

  if dotfiles install
  then
    ok 'dotfiles installed'
  else
    revertInstall 'Failed to install dotfiles'
  fi
}

# Main installation routine.
function main() {
  local sudoPassword

  info 'dotfiles installation started'

  sudoPassword="$(getSudoPassword)"
  refreshSudo "$sudoPassword"

  checkInstallationDependencies
  dotfilesIsNotInstalled

  updateDependencyRepository

  refreshSudo "$sudoPassword" # Refresh to prevent sudo timeout if repository update was slow.

  installDependencies
  installDotfiles

  info 'dotfiles installation complete. Restart terminal to activate.'
}

# Revert dotfiles installation on failure and stop execution.
#
# $1 - The error message to display after reverting.
function revertInstall() {
  warn 'Installation terminated, reverting install'

  if [[ -f $DOTFILES_COMMAND_TARGET ]]
  then
    rm -f "$DOTFILES_COMMAND_TARGET" &>/dev/null
  fi

  if [[ -d $DOTFILES_PATH ]]
  then
    rm -rf "$DOTFILES_PATH" &>/dev/null
  fi

  die "$1"
}

# Update the macports dependency repository
function updateDependencyRepository() {
  info 'Updating dependency repository'

  if ! sudo port -N selfupdate
  then
    die 'Failed to update dependency repository'
  fi

  ok 'Dependency repository updated'
}

################################################################################

main
