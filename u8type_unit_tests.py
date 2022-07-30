#!/usr/bin/env python
import unittest
from Beeb import Beeb
buildDir = 'build/'
binaryName = 'u8type'
beeb = Beeb(buildDir + binaryName)

class UnitTestU8type(unittest.TestCase):

    def run_checkBytes(self, in_list, out_a, out_flags, utf16=None):
        memory = beeb.setupMemory()
        while len(in_list) > 0:
            in_reg = in_list.pop(0)
            (cycles, a, x, y) = beeb.runCode(memory, 'checkBytes', a=in_reg['a'], x=in_reg['x'], y=in_reg['y'])
        self.assertEqual(a, out_a)
        self.assertEqual(beeb.getByte(memory, beeb.getAddr('flags')), out_flags)
        if utf16 is not None:
            self.assertEqual(beeb.getHalfWord(memory, beeb.getAddr('utf16')), utf16)

    def test_lineending_detection(self):
        # Line endings happy paths
        self.run_checkBytes([{'a': 0x0a, 'x': 0xff, 'y': 0xff}], 1, 0x01)
        self.run_checkBytes([{'a': 0x0d, 'x': 0xff, 'y': 0xff}], 1, 0x02)
        self.run_checkBytes([{'a': 0x0d, 'x': 0x0a, 'y': 0xff}], 2, 0x04)

        # Sad path
        #self.run_checkBytes([{'a': 0xff, 'x': 0xff, 'y': 0xff}], 1, 0x80)

        # Set all flags
        #self.run_checkBytes([{'a': 0x0a, 'x': 0xff, 'y': 0xff},
        #                     {'a': 0x0d, 'x': 0xff, 'y': 0xff},
        #                     {'a': 0x0d, 'x': 0x0a, 'y': 0xff}], 2, 0x07)

    def test_single_bytes(self):
        self.run_checkBytes([{'a': 0x0a, 'x': 0x00, 'y': 0x00}], 1, 0x01)
        self.run_checkBytes([{'a': 0x0d, 'x': 0x00, 'y': 0x00}], 1, 0x02)

    def test_chris(self):
        memory = beeb.setupMemory()
        beeb.runCode(memory, 'setFlagsAndReturnSingle', a=0x01)
        (cycles, a, x, y) = beeb.runCode(memory, 'setFlagsAndReturnSingle', a=0x02)
        print(beeb.getByte(memory, beeb.getAddr('flags')))
