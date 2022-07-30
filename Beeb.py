#!/usr/bin/env python

import subprocess

from py65emu.cpu import CPU
from py65emu.mmu import MMU

class Beeb:
    def __init__(self, asmName):
        # TODO execution address?
        self.asmName = asmName
        with open(asmName + '.txt', 'r') as ft:
            self.fileText = ft.readlines()

    def getAddr(self, label):
        foundLine = False
        for line in self.fileText:
            if foundLine:
                return int(line.lstrip().split(' ')[0], 16)
            elif line.strip() == '.' + label:
                foundLine = True
        if not foundLine:
            raise Exception('Addr not found')

    def getByte(self, mmu, address):
        (block, idx) = self.getBlockOffset(address)
        return mmu.blocks[block]['memory'][idx]

    def setByte(self, mmu, address, val):
        assert(val <= 0xff)
        (block, idx) = self.getBlockOffset(address)
        mmu.blocks[block]['memory'][idx] = val

    def getHalfWord(self, mmu, address):
        (block, idx) = self.getBlockOffset(address)
        return mmu.blocks[block]['memory'][idx] + (mmu.blocks[block]['memory'][idx+1] << 8)

    def setHalfWord(self, mmu, address, val):
        assert(val <= 0xffff)
        (block, idx) = self.getBlockOffset(address)
        mmu.blocks[block]['memory'][idx] = val & 0xff
        mmu.blocks[block]['memory'][idx+1] = val >> 8

    def getBlockOffset(self, address):
        if address < 0x2000:
            return (0, address)
        elif address < 0x8000:
            return (1, address - 0x2000)
        else:
            return (2, address - 0x8000)

    def setupMemory(self):
        with open(self.asmName, "rb") as fileBinary:
            mmu = MMU([
                (0x0000, 0x2000),
                (0x2000, 0x6000, False, fileBinary), # Allow self modifying code
                (0x8000, 0x8000)
            ])

        mmu.blocks[2]['memory'][0x7fee] = 0x60 # hack RTS for oswrch
        return mmu

    def getFlags(self, cpu):
        flagString = ''
        flagString += 'N' if cpu.r.getFlag('N') else ' '
        flagString += 'V' if cpu.r.getFlag('V') else ' '
        flagString += 'B' if cpu.r.getFlag('B') else ' '
        flagString += 'D' if cpu.r.getFlag('D') else ' '
        flagString += 'I' if cpu.r.getFlag('I') else ' '
        flagString += 'Z' if cpu.r.getFlag('Z') else ' '
        flagString += 'C' if cpu.r.getFlag('C') else ' '
        return flagString

    def runCode(self, mmu, function, debug=False, a=0, x=0, y=0):
        address = self.getAddr(function)
        cpu = CPU(mmu, address)
        cycles = 0
        cpu.r.a = a
        cpu.r.x = x
        cpu.r.y = y

        while cpu.r.pc != 1:
            if debug:
                print('a=%02x x=%02x y=%02x s=%02x pc=%02x flags=%s cycles=%d' % (cpu.r.a, cpu.r.x, cpu.r.y, cpu.r.s, cpu.r.pc, self.getFlags(cpu), cpu.cc))
                print(''.join([line.strip() for line in self.fileText if line.lstrip().lower().startswith(hex(cpu.r.pc)[2:])]))
            cpu.step()
            cycles += cpu.cc
        if debug:
            print('a=%02x x=%02x y=%02x s=%02x pc=%02x flags=%s cycles=%d' % (cpu.r.a, cpu.r.x, cpu.r.y, cpu.r.s, cpu.r.pc, self.getFlags(cpu), cpu.cc))
        return (cycles, cpu.r.a, cpu.r.x, cpu.r.y)

    def runBeebjit(self, ssdFilename, beebCommands, debug=False):
        rawCommands = [command.encode('ascii') for command in beebCommands]
        sp = subprocess.Popen(['beebjit', '-0', ssdFilename, '-terminal', '-headless'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        sp.stdin.write(b'\n'.join(rawCommands) + b'\n\n')
        sp.stdin.flush()

        foundCommand = False
        store = []
        while True:
            lineRead = sp.stdout.readline()
            if debug:
                print(lineRead)
            store.append(lineRead)
            if foundCommand:
                break
            if rawCommands[-1] in store[-1]:
                foundCommand = True

        sp.stdin.close()
        sp.stdout.close()
        sp.terminate()
        if debug:
            print(store[-1])
        return store[-1].decode('ascii')
