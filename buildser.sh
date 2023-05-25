#!/bin/sh
set -e

# git clone https://github.com/stardot/beebasm.git
# git clone https://github.com/scarybeasts/beebjit.git
# git clone https://github.com/sweharris/MMB_Utils.git
# git clone https://github.com/docmarionum1/py65emu.git

export PATH=$PATH:$PWD/../MMB_Utils:$PWD/../beebasm:$PWD/../beebjit
export PYTHONPATH=$PWD/../py65emu

ln -sf ../beebjit/roms
mkdir -p build

cd build
beebasm -v -i ../u8ser.asm > u8ser.txt
beebasm -i ../u8ser.asm -do u8ser.ssd
cd ..

python3 -m unittest u8ser_unit_tests.UnitTestU8ser
