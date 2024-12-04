#!/bin/zsh
#
# Initialize system and install dotfiles

LOCAL_PATH="$HOME/.local"
BIN_PATH="${LOCAL_PATH}/bin"
ETC_PATH="${LOCAL_PATH}/etc"
OPT_PATH="${LOCAL_PATH}/opt"

DEPENDENCIES=('brew' 'port' 'git' 'zsh')

DOTFILES_REPOSITORY=https://github.com/lojoja/dotfiles
DOTFILES_DEPENDENCIES=('python312' 'py312-pip' 'py312-ansible') # Dotfiles dependencies are port names
typeset -A DOTFILES_DEPENDENCIES_SELECT=('python312' 'python3::python312' 'py312-pip' 'pip::pip312' 'py312-ansible' 'ansible::py312-ansible')
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
  'yellow' $(tput setaf 3)
  'blue' $(tput setaf 4)
  'magenta' $(tput setaf 5)
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

# Print a stylized message prefixed with "Warning: ".
#
# $1 - The message to print. Default is "Undefined".
function warn() {
  print >&2
  print "$STYLES[yellow]$STYLES[bold]Warning:$STYLES[reset] ${1:-"Undefined"}" >&2
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

#####################
# Utility Functions #
#####################

# Prompt for sudo password. Password is printed to be captured by caller.
function getSudoPassword() {
  local sudoPassword

  while true
  do
    print >&2
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
    if ! sudo port -N install $dependency && sudo port -N select --set ${(@s/::/)DOTFILES_DEPENDENCIES_SELECT[$dependency]}
    then
      die "Failed to install $dependency"
    fi

    ok "$dependency installed"
  done
}

# Install dotfiles.
function installDotfiles() {
  info 'Installing dotfiles'

  if mkdir -p "$LOCAL_PATH" "$BIN_PATH" "$ETC_PATH" "$OPT_PATH" &>/dev/null
  then
    ok 'Local paths exist'
  else
    die 'Failed to create local paths'
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

  if "$DOTFILES_COMMAND_TARGET" install
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
