#!/usr/bin/env python
import os
import unittest
from Beeb import Beeb
buildDir = 'build/'
binaryName = 'u8rom'
beeb = Beeb(buildDir + binaryName)

class IntegrationTestU8rom(unittest.TestCase):
    outputSsd = 'integrationTest.ssd'
    textFilename = 'txtutf8'

    def createTestSsd(self, utf8text=None, textBinary=None):
        os.system('cp blank.ssd ' + buildDir + self.outputSsd)
        if utf8text is not None:
            textBinary = utf8text.encode('utf-8')
        if textBinary is not None:
            with open(buildDir + self.textFilename, 'wb') as fileOut:
                fileOut.write(textBinary)
            os.system('beeb putfile ' + buildDir + self.outputSsd + ' ' + buildDir + self.textFilename)
            #os.system('beeb putfile ' + buildDir + self.outputSsd + ' ' + buildDir + 'testtext')

    def test_help(self):
        commandOutput = beeb.runBeebjit(None, ['*HELP'], romFilename=buildDir + binaryName, linesFollowingCommand=6)
        self.assertEqual('UTF-8 Tools\n', commandOutput.split('\r')[1])

    def test_noParameter(self):
        commandOutput = beeb.runBeebjit('blank.ssd', ['*U8TYPE'], romFilename=buildDir + binaryName)
        # TODO

    def test_invalidFilename(self):
        commandOutput = beeb.runBeebjit('blank.ssd', ['*U8TYPE FRED'], romFilename=buildDir + binaryName)
        self.assertEqual('File not found\n', commandOutput.split('\r')[1])

    def test_emptyFile(self):
        self.createTestSsd('')
        commandOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*U8TYPE ' + self.textFilename], romFilename=buildDir + binaryName)
        self.assertEqual('File is 0 length\n', commandOutput.split('\r')[1])

    def test_asciiFile(self):
        self.createTestSsd('ABC\n')
        commandOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*U8TYPE ' + self.textFilename], romFilename=buildDir + binaryName)
        self.assertEqual('ABC\n', commandOutput.split('\r')[1])

    def test_unicodeRepeat(self):
        self.createTestSsd('A|€|€|B') # bar in first slot, euro in second slot
        # TODO doesn't work yet as charSlots in read-only memory!
