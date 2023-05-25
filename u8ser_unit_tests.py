#!/usr/bin/env python
import unittest
from Beeb import Beeb
buildDir = 'build/'
binaryName = 'u8ser'
beeb = Beeb(buildDir + binaryName)

class UnitTestU8ser(unittest.TestCase):
    def test_topofrange(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=48)
        self.assertEqual(a, 0) # no colour output

    def test_whitebg(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=47)
        self.assertEqual(a, 135)

    def test_blackbg(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=40)
        self.assertEqual(a, 128)

    def test_between1(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=39)
        self.assertEqual(a, 1) # no colour output

    def test_between2(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=38)
        self.assertEqual(a, 0) # no colour output

    def test_whitefg(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=37)
        self.assertEqual(a, 7)

    def test_blackfg(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=30)
        self.assertEqual(a, 0)

    def test_reset(self):
        memory = beeb.setupMemory()
        (cycles, a, x, y) = beeb.runCode(memory, 'esc5bColour', a=0)
        self.assertEqual(a, 128) # black bg
