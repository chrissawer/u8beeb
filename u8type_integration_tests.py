#!/usr/bin/env python
import os
import unittest
from Beeb import Beeb
buildDir = 'build/'
binaryName = 'u8type'
beeb = Beeb(buildDir + binaryName)

class IntegrationTestU8type(unittest.TestCase):
    inputSsd = binaryName + '.ssd'
    outputSsd = 'integrationTest.ssd'
    textFilename = 'txtutf8'

    def createTestSsd(self, utf8text=None, textBinary=None):
        os.system('cp ' + buildDir + self.inputSsd + ' ' + buildDir + self.outputSsd)
        if utf8text is not None:
            textBinary = utf8text.encode('utf-8')
        if textBinary is not None:
            with open(buildDir + self.textFilename, 'wb') as fileOut:
                fileOut.write(textBinary)
            os.system('beeb putfile ' + buildDir + self.outputSsd + ' ' + buildDir + self.textFilename)
            #os.system('beeb putfile ' + buildDir + self.outputSsd + ' ' + buildDir + 'testtext')

    def test_noParameter(self):
        self.createTestSsd()
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type'])
        self.assertEqual('No parameter supplied', chrisOutput.split('\r')[1])

    def test_invalidFilename(self):
        self.createTestSsd()
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type invalid'])
        self.assertEqual('File not found', chrisOutput.split('\r')[1])

    def test_emptyFile(self):
        self.createTestSsd('')
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename])
        self.assertEqual('File is 0 length', chrisOutput.split('\r')[1])

    def test_asciiNewlines(self):
        self.createTestSsd("A\nB\rC\r\nD\n\rE\n") # \r\n = DOS linefeed
        command = '*u8type ' + self.textFilename
        beebBuffer = beeb.runBeebjit(buildDir + self.outputSsd, [command, 'PRINT'], returnFullBuffer=True)
        self.assertEqual('>' + command, beebBuffer[0])
        self.assertEqual('A', beebBuffer[1])
        self.assertEqual('B', beebBuffer[2])
        self.assertEqual('C', beebBuffer[3])
        self.assertEqual('D', beebBuffer[4])
        self.assertEqual('',  beebBuffer[5])
        self.assertEqual('E', beebBuffer[6])

    def test_asciiRemap(self): # A few ASCII characters '|` remap to Unicode versions
        charToTest = '|'
        self.createTestSsd('A' + charToTest + 'B')
        charSlotsAddr = '%X' % beeb.getAddr('charSlots')
        charSlotsAddrN = '%X' % (beeb.getAddr('charSlots') + 1)
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename, 'PRINT ~?&' + charSlotsAddr + ', ~?&' + charSlotsAddrN])
        outputBytes = chrisOutput.strip().split()
        self.assertEqual('%X' % charToTest.encode('utf-16-le')[0], outputBytes[0])
        self.assertEqual('%X' % charToTest.encode('utf-16-le')[1], outputBytes[1])

    def test_unicodePresent(self):
        charToTest = '€' #charToTest = 'é'
        self.createTestSsd('A' + charToTest + 'B')
        charSlotsAddr = '%X' % beeb.getAddr('charSlots')
        charSlotsAddrN = '%X' % (beeb.getAddr('charSlots') + 1)
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename, 'PRINT ~?&' + charSlotsAddr + ', ~?&' + charSlotsAddrN])
        outputBytes = chrisOutput.strip().split()
        self.assertEqual('%X' % charToTest.encode('utf-16-le')[0], outputBytes[0])
        self.assertEqual('%X' % charToTest.encode('utf-16-le')[1], outputBytes[1])

    def test_unicodeMissing(self):
        self.createTestSsd('AБB')
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename])
        outputBytes = chrisOutput.strip().split()
        self.assertEqual('AXB>\n', chrisOutput.split('\r')[1]) # No newline yet

    def test_unicodeRepeat(self):
        self.createTestSsd('A|€|€|B') # bar in first slot, euro in second slot
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename,
                                                                  'PRINT ~?&' + '%X' % (beeb.getAddr('charSlots')) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 1) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 2) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 3) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 4) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 5)])
        outputBytes = chrisOutput.strip().split()
        self.assertEqual('%X' % '|'.encode('utf-16-le')[0], outputBytes[0])
        self.assertEqual('%X' % '|'.encode('utf-16-le')[1], outputBytes[1])
        self.assertEqual('%X' % '€'.encode('utf-16-le')[0], outputBytes[2])
        self.assertEqual('%X' % '€'.encode('utf-16-le')[1], outputBytes[3])
        self.assertEqual('FF', outputBytes[4])
        self.assertEqual('FF', outputBytes[5])

    def test_unicodeSlotReuse(self):
        #self.createTestSsd('ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞß')
        #self.createTestSsd('àáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ')
        #self.createTestSsd('¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿')
        #self.createTestSsd('ŒœŴŵŶŷ‘’“”„–—†‡•…‰‹›€™')

        #self.createTestSsd('àáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ|€') # 34 characters - bar reuses first slot, euro second
        self.createTestSsd('àáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞß|€') # same but 66 - check wrap
        chrisOutput = beeb.runBeebjit(buildDir + self.outputSsd, ['*u8type ' + self.textFilename,
                                                                  'PRINT ~?&' + '%X' % (beeb.getAddr('charSlots')) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 1) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 2) +
                                                                      ', ~?&' + '%X' % (beeb.getAddr('charSlots') + 3)])
        outputBytes = chrisOutput.strip().split()
        self.assertEqual('%X' % '|'.encode('utf-16-le')[0], outputBytes[0])
        self.assertEqual('%X' % '|'.encode('utf-16-le')[1], outputBytes[1])
        self.assertEqual('%X' % '€'.encode('utf-16-le')[0], outputBytes[2])
        self.assertEqual('%X' % '€'.encode('utf-16-le')[1], outputBytes[3])
