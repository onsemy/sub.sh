#!/bin/bash
# vim:ft=sh:et:ts=2:sw=2:sts=2:
#
# sub.sh
# ~~~~~~
#
# Shortest way to provision a Linux environment as for my taste:
#
#  $ curl -sL sub.sh | bash [-s - [~/.sub.sh] OPTIONS]
#  $ wget -qO- sub.sh | bash [-s - [~/.sub.sh] OPTIONS]
#
set -euo pipefail
{
readonly TIMESTAMP="$(date +%s)"
readonly USER="$(whoami)"
readonly SUBSH=~/.sub.sh
readonly VIRTUALENV=~/env

# Where some backup files to be stored.
readonly BAK=~/.sub.sh-bak-$TIMESTAMP

# Don't update APT if the last updated time is in a day.
readonly UPDATE_APT_AFTER=86400
readonly APT_UPDATED_AT=~/.sub.sh-apt-updated-at

help() {
  # Print the help message for --help.
  echo "Usage: curl -sL sub.sh | bash [-s - [~/.sub.sh] OPTIONS]"
  echo
  echo "Options:"
  echo "  --help              Show this message and exit."
  echo "  --no-python         Do not setup Python environment."
  echo "  --no-apt-update     Do not update APT package lists."
  echo "  --force-apt-update  Update APT package lists on regardless of"
  echo "                      updating period."
}

# Parse options.
PYTHON=true
APT_UPDATE=auto
SUBSH_DEST_SET=false
SUBSH_DEST="$SUBSH"

for i in "$@"
do
  case $i in
    --help)
      help
      exit;;

    --no-python)
      PYTHON=false
      shift;;

    --no-apt-update)
      APT_UPDATE=false
      shift;;

    --force-apt-update)
      APT_UPDATE=true
      shift;;

    *)
      if [[ "$SUBSH_DEST_SET" == false ]]
      then
        SUBSH_DEST_SET=true
        SUBSH_DEST="$i"
        shift
      else
        help
        exit
      fi
      ;;
  esac
done

readonly SUBSH_DEST="$(readlink -f "$SUBSH_DEST")"

# =============================================================================
# Functions
# =============================================================================

# print -----------------------------------------------------------------------

if [[ -z "$TERM" ]]
then
  secho() {
    echo "$2"
  }
else
  secho() {
    echo -e "$(tput setaf "$1")$2$(tput sgr0)"
  }
fi

info() {
  # Print an information log.
  secho 6 "$1"
}

WARNED=0
warn() {
  # Print a yellow colored error message.
  secho 3 "$1"
  WARNED=$((WARNED+1))
}

err() {
  # Print a red colored error message.
  secho 1 "$1"
}

fatal() {
  # Print a red colored error message and exit the script.
  err "$@"
  exit 1
}

# version detectors -----------------------------------------------------------

vim-installed-version() {
  vim --version | awk '{ print $5; exit }'
}

git-installed-version() {
  git --version | awk '{ print $3 }'
}

rg-installed-version() {
  rg --version | head -n 1 | cut -d' ' -f2
}

fd-installed-version() {
  fd --version | cut -d' ' -f2
}

# other utilities -------------------------------------------------------------

add-ppa() {
  local src="$1"

  if ! grep -q "^deb.*$src" /etc/apt/sources.list.d/*.list
  then
    sudo -E add-apt-repository -y "ppa:$src"
  fi
}

git-pull() {
  # Clone a Git repository.  If the repository already exists,
  # just pull from the remote.
  local src="$1"
  local dest="$2"

  if [[ ! -d "$dest" ]]
  then
    mkdir -p "$dest"
    git clone "$src" "$dest"
  else
    git -C "$dest" pull
  fi
}

github-pull() {
  git-pull "https://github.com/$1" "$2"
}

github-api() {
  local user="${GITHUB_USER:-}"
  local token="${GITHUB_TOKEN:-}"
  curl -su "$user:$token" "https://api.github.com/repos/$1"
}

sym-link() {
  # Make a symbolic link.  If something should be backed up at
  # the destination path, it moves that to $BAK.
  local src="$1"
  local dest="$2"

  if [[ -e $dest || -L $dest ]]
  then
    if [[ "$(readlink -f "$src")" == "$(readlink -f "$dest")" ]]
    then
      echo "Already linked '$dest'"
      return
    fi

    mkdir -p "$BAK"
    mv "$dest" "$BAK"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -vs "$src" "$dest"
}

executable() {
  which "$1" &>/dev/null
}

failed() {
  fatal "Failed to provision by sub.sh."
}
trap failed ERR

# =============================================================================
# Provisioning
# =============================================================================

# Go to the home directory.  A current working directory
# may deny access from this user.
cd ~

# sudo ------------------------------------------------------------------------

require_sudo_without_password() {
  if ! executable sudo
  then
    info "Installing sudo..."
    apt update
    apt install -y sudo
  fi

  # Check if sudo requires password.
  if ! >&/dev/null sudo -n true
  then
    err "Make sure $USER can use sudo without password."
    echo
    err "  # echo '$USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-$USER"
    echo

    return 1
  fi
}

require_sudo_without_password

# apt -------------------------------------------------------------------------

update_apt() {
  info "Updating APT package lists..."

  # Require to add PPAs.
  sudo -E apt update
  sudo -E apt install -y software-properties-common

  # Prefer the latest version of Git.
  add-ppa git-core/ppa

  # Update the APT package lists.
  sudo -E apt update
}

install_apt_packages() {
  info "Installing packages from APT..."

  sudo -E apt install -y \
    aptitude \
    cmake \
    curl \
    git \
    git-flow \
    htop \
    iftop \
    iputils-ping \
    jq \
    less \
    lsof \
    man \
    net-tools \
    ntpdate \
    psmisc \
    telnet \
    tmux \
    tree

  sudo -E apt install -y shellcheck || true
}

# Install packages from APT.
if [[ "$APT_UPDATE" != false ]]
then
  if [[ "$APT_UPDATE" == auto && -f $APT_UPDATED_AT ]]
  then
    readonly APT_UPDATED_BEFORE="$((TIMESTAMP - $(cat "$APT_UPDATED_AT")))"
  else
    readonly APT_UPDATED_BEFORE="$((UPDATE_APT_AFTER + 1))"
  fi

  if [[ $APT_UPDATED_BEFORE -gt $UPDATE_APT_AFTER ]]
  then
    update_apt
    echo "$TIMESTAMP" > "$APT_UPDATED_AT"
  fi
fi

install_apt_packages

# localhost ssh ---------------------------------------------------------------

# Authorize the local SSH key for connecting to localhost without password.
if ! ssh -qo BatchMode=yes localhost true
then
  mkdir -p ~/.ssh

  if [[ ! -f ~/.ssh/id_rsa ]]
  then
    info "Generating new SSH key..."
    ssh-keygen -f ~/.ssh/id_rsa -N ''
  fi

  if [[ ! -f ~/.ssh/id_rsa.pub ]]
  then
    info "Retrieving a public SSH key from the private..."
    ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
  fi

  ssh-keyscan -H localhost 2>/dev/null 1>> ~/.ssh/known_hosts
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

  info "Authorized the SSH key to connect to localhost."
fi

# zsh -------------------------------------------------------------------------

if ! executable zsh
then
  info "Installing ZSH..."
  sudo -E apt install -y zsh
fi

info "Setting up the ZSH environment..."

sudo -E chsh -s "$(which zsh)" "$USER"

# Oh My ZSH!
github-pull robbyrussell/oh-my-zsh ~/.oh-my-zsh

github-pull \
  zsh-users/zsh-syntax-highlighting \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

github-pull \
  zsh-users/zsh-autosuggestions \
  ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

github-pull \
  bobthecow/git-flow-completion \
  ~/.oh-my-zsh/custom/plugins/git-flow-completion

# rg --------------------------------------------------------------------------

# "rg" is a short-term for "ripgrep", which is a "grep" alternative.

install_rg() {
  # Detect the latest and installed version.
  info "Detecting the latest version of rg..."

  local rg_version
  local rg_release
  rg_version="$(
    github-api BurntSushi/ripgrep/releases | \
    grep -oP '(?<=tag_name": ")[0-9.]+' | head -1
  )"
  rg_release="$(github-api "BurntSushi/ripgrep/releases/tags/$rg_version")"

  # Compare with the currently installed version.
  if executable rg && [[ "$(rg-installed-version)" == "$rg_version" ]]
  then
    info "Already installed rg-${rg_version}"
    return
  fi

  info "Installing rg-${rg_version}..."

  local rg_tgz
  local rg_dir
  local rg_tgz_url

  rg_tgz="$(mktemp -t rg-XXX.tar.gz)"
  rg_dir="$(mktemp -dt rg-XXX)"
  rg_tgz_url="$(
    echo "$rg_release" | \
    grep -e "download_url.\+$(uname -m).\+linux.\+" | \
    cut -d'"' -f4
  )"

  info "Downloading ${rg_tgz_url} at ${rg_tgz}..."
  curl -L "$rg_tgz_url" -o "$rg_tgz"

  info "Decompressing ${rg_tgz}..."
  tar xvzf "$rg_tgz" -C "$rg_dir"

  info "Installing rg executable..."
  sudo -E cp "$rg_dir/"*"/rg" /usr/local/bin/rg

  echo "Installed at $(which rg)."
}

install_rg

# fd --------------------------------------------------------------------------

# "fd" is a "find" alternative.

install_fd() {
  # Remove legacy executable.
  if [[ -f /usr/local/bin/fd ]]
  then
    sudo -E rm -rf /usr/local/bin/fd
  fi

  # Detect the latest and installed version.
  info "Detecting the latest version of fd..."

  local fd_release
  local fd_version
  fd_release="$(github-api sharkdp/fd/releases/latest)"
  fd_version="$(
    echo "$fd_release" | grep tag_name | cut -d '"' -f4 | cut -c 2-
  )"

  if executable fd && [[ "$(fd-installed-version)" == "$fd_version" ]]
  then
    info "Already installed fd-${fd_version}"
    return
  fi

  info "Installing fd-${fd_version}..."

  local fd_deb
  local fd_deb_url

  fd_deb="$(mktemp -t fd-XXX.deb)"
  fd_deb_url="$(
    echo "$fd_release" | \
    grep -e "download_url.\+fd_.\+$(dpkg --print-architecture)\.deb\"" | \
    cut -d'"' -f4
  )"

  info "Downloading ${fd_deb_url} at ${fd_deb}..."
  curl -L "$fd_deb_url" -o "$fd_deb"

  info "Installing ${fd_deb}..."
  sudo -E dpkg -i "$fd_deb"

  echo "Installed at $(which fd)."
}

install_fd

# vim -------------------------------------------------------------------------

# Upgrade Vim.
INSTALL_VIM=true
VIM_VERSION=""
if executable vim
then
  VIM_VERSION="$(vim-installed-version)"
  if [[ "$VIM_VERSION" = 8.* ]]
  then
    INSTALL_VIM=false
  fi
fi

if [[ "$INSTALL_VIM" != false ]]
then
  if [[ -z "$VIM_VERSION" ]]
  then
    info "Installing Vim..."
  else
    info "Upgrading Vim from ${vim-installed-version}..."
  fi

  add-ppa pi-rho/dev

  sudo -E apt update
  sudo -E apt install -y vim
fi

# sub.sh ----------------------------------------------------------------------

# Get sub.sh.
info "Getting sub.sh at $SUBSH_DEST..."
github-pull sublee/sub.sh "$SUBSH_DEST"
if [[ "$SUBSH_DEST_SET" == true ]]
then
  sym-link "$SUBSH_DEST" "$SUBSH"
fi

# Apply sub.sh.
info "Linking dot files from sub.sh..."
git config --global include.path "$SUBSH/git-aliases"
sym-link "$SUBSH/profile" ~/.profile
sym-link "$SUBSH/zshrc" ~/.zshrc
sym-link "$SUBSH/sublee.zsh-theme" ~/.oh-my-zsh/custom/sublee.zsh-theme
sym-link "$SUBSH/vimrc" ~/.vimrc
sym-link "$SUBSH/tmux.conf" ~/.tmux.conf && (tmux source ~/.tmux.conf || true)

# plugins for vim and tmux ----------------------------------------------------

info "Installing plugins for Vim and tmux..."

# Vim-Plug for Vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim --noplugin -c PlugInstall -c qa
stty -F /dev/stdout sane

# TPM for tmux
github-pull tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/scripts/install_plugins.sh

# python ----------------------------------------------------------------------

# Setup a Python environment.
if [[ "$PYTHON" = true ]]
then
  info "Setting up the Python environment..."

  sudo -E apt install -y python python-dev python-setuptools

  if ! executable pyenv
  then
    curl -L https://git.io/vxZax | bash
  fi

  sym-link \
    "$SUBSH/python-startup.py" \
    ~/.python-startup

  readonly SITE_PACKAGES=$(
    python -c \
    'from distutils.sysconfig import get_python_lib; print(get_python_lib())'
  )
  sym-link \
    "$SUBSH/python-debug.pth" \
    "$SITE_PACKAGES/__debug__.pth"
fi

# results ---------------------------------------------------------------------

# Show my emblem.
if [[ -n "$TERM" ]]
then
  curl -sL https://subl.ee/~emblem
fi

# Print installed versions.
echo "sub.sh: $(git -C "$SUBSH" rev-parse --short HEAD) at $SUBSH_DEST"
echo "vim: $(vim-installed-version)"
echo "git: $(git-installed-version)"
echo "rg: $(rg-installed-version)"
echo "fd: $(fd-installed-version)"

# Notify the result.
info "Provisioned successfully by sub.sh."
if [[ "$WARNED" -eq 1 ]]
then
  warn "But there was 1 warning."
elif [[ "$WARNED" -gt 1 ]]
then
  warn "But there were $WARNED warnings."
fi
if [[ -d "$BAK" ]]
then
  info "Backup files are stored in $BAK"
fi
if [[ "$SHELL" != "$(which zsh)" && -z "${ZSH+x}" ]]
then
  info "To use just provisioned ZSH, relogin or"
  echo
  info "  $ zsh"
  echo
fi
}
