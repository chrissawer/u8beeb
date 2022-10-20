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
beebasm -v -i ../u8type.asm > u8type.txt
beebasm -i ../u8type.asm -do u8type.ssd
cd ..

python3 -m unittest u8type_unit_tests.UnitTestU8type
python3 -m unittest u8type_integration_tests.IntegrationTestU8type
#python3 -m unittest u8type_integration_tests.IntegrationTestU8type.test_unicodeSlotReuse
