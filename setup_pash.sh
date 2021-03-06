#!/usr/bin/env sh

# Ensure that the script fails if something failed
set -e

# Install dependencies locally.
PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')
URL='https://github.com/binpash/pash/archive/refs/heads/main.zip'
VERSION='latest'
DL=$(command -v curl >/dev/null 2>&1 && echo curl || echo 'wget -qO-')

cmd_exists () {
  command -v $1 >/dev/null 2>&1 && echo 'true' || echo 'false';
}

if [ "$PLATFORM" = "darwin" ]; then
  echo 'PaSh is not yet well supported on OS X'
  exit 1
fi

# Let script fail if repository cannot be cloned.
set +e
git clone git@github.com:binpash/pash.git
if [ $? -ne 0 ]; then
  echo 'SSH clone failed; attempting HTTPS'
  git clone https://github.com/andromeda/pash.git
fi
set -e

cd pash/scripts

# Switch to EuroSys 2021 frozen branch.
git checkout eurosys-2021-aec-frozen

# Only install PaSh if we are in the sudo group, otherwise everything fails.
if [ $(groups $(whoami) | grep -c "sudo\|root\|admin") -ge 1 ]; then
  # Copy new install script over and run it.
  cp ../../install.sh install.sh
  bash install.sh -p
fi

