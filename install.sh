#!/usr/bin/env bash

# Ensure that the script fails if something failed
set -e

# Log installs 
LOG_DIR=$PWD/install_logs
mkdir -p $LOG_DIR


# Determine if installs need to be performed.
prepare_sudo_install_flag=0
while getopts 'p' opt; do
    case $opt in
        p) prepare_sudo_install_flag=1 ;;
        *) echo 'Error in command line parsing' >&2
           exit 1
    esac
done
shift "$(( OPTIND - 1 ))"


git submodule init
git submodule update

# Install packages if -p flag is specified.
if [ "$prepare_sudo_install_flag" -eq 1 ]; then
    echo "Running preparation sudo apt install and opam init:"
    echo "|-- running apt update..."
    sudo apt-get update &> $LOG_DIR/apt_update.log
    echo "|-- running apt install..."
    sudo apt-get install -y libtool m4 automake opam pkg-config libffi-dev python3 python3-pip wamerican-insane bc bsdmainutils &> $LOG_DIR/apt_install.log
    yes | opam init &> $LOG_DIR/opam_init.log
else
    echo "Requires libtool, m4, automake, opam, pkg-config, libffi-dev, python3, pip for python3, a dictionary, bc, bsdmainutils"
    echo "Ensure that you have them by running:"
    echo "  sudo apt install libtool m4 automake opam pkg-config libffi-dev python3 python3-pip wamerican-insane bc bsdmainutils"
    echo "  opam init"
    echo -n "Press 'y' if you have these dependencies installed. "
    while : ; do
        read -n 1 k <&1
        if [[ $k = y ]] ; then
            echo ""
            echo "Proceeding..."
            break
        fi
    done
fi


# Move back to root and exort path as PASH_TOP.
cd ..
export PASH_TOP=$PWD

# Build the parser (requires libtool, m4, automake, opam)
echo "Building parser..."
eval $(opam config env)
cd compiler/parser
echo "|-- installing opam dependencies..."
make opam-dependencies &> $LOG_DIR/make_opam_dependencies.log
echo "|-- making libdash... (requires sudo)"

make libdash &> $LOG_DIR/make_libdash.log
echo "|-- making parser..."

make &> $LOG_DIR/make.log
cd ../../

# Build runtime tools: eager, split
echo "Building runtime..."
cd runtime/
make &> $LOG_DIR/make.log
cd ../

# Install python3 dependencies.
echo "Installing python dependencies..."
python3 -m pip install jsonpickle &> $LOG_DIR/pip_install_jsonpickle.log
python3 -m pip install -U PyYAML &> $LOG_DIR/pip_install_pyyaml.log
python3 -m pip install numpy &> $LOG_DIR/pip_install_numpy.log
python3 -m pip install matplotlib &> $LOG_DIR/pip_install_matplotlib.log

sudo apt-get install -y p7zip-full
echo "Installing web-index dependencies..."

# pandoc v.2.2.1
wget https://github.com/jgm/pandoc/releases/download/2.2.1/pandoc-2.2.1-1-$(dpkg --print-architecture).deb
sudo dpkg -i ./pandoc-2.2.1-1-$(dpkg --print-architecture).deb
rm ./pandoc-2.2.1-1-$(dpkg --print-architecture).deb 

# node version 10+ does not need external npm
sudo apt-get install -y curl 
curl -fsSL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt-get install -y nodejs
cd  $PASH_TOP/evaluation/scripts/web-index
npm install
cd $PASH_TOP

# Generate small dataset inputs.
echo "Generating input files..."
cd evaluation/scripts/input
./gen.sh
cd ../../../

# This is necessary for the parser to link to libdash
echo "Do not forget to export LD_LIBRARY_PATH as shown below :)"
set -v
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib/"
set -v

# This is necessary for the program to scripts to actually work.
echo "Do not forget to export PASH_TOP as shown below :)"
echo "export PASH_TOP=\"${PASH_TOP}\""
