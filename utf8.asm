CUSTOM_CHAR_START = &E0

.readParameter \ return 0 in A for success, non-0 for failure
    LDA #1
    LDY #0
    LDX #controlBlock
    JSR osargs \ AUG p337, returns parameters space separated, &0D terminated
    LDA (controlBlock),Y
    CMP #&D
    BNE readParameterOk
    LDA #1 \ error 1 and return not ok
    JSR printError
    RTS
.readParameterOk
    LDA #0 \ return ok
    RTS

.openFile
    LDA #&40
    LDX controlBlock
    LDY controlBlock+1
    JSR osfind \ ADUG p178 "OSFIND Open a File", needs filename pointer in controlBlock
    BNE openFileOk
    LDA #2 \ error 2 and return not ok
    JSR printError
    RTS
.openFileOk
    STA fileHandle
    LDA #0 \ return ok
    RTS

.readContents
    \ TODO macroify this
    \ ADUG p188 "OSFSC Check EOF" [A/Y destroyed, X ret val]
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ zeroByteFile

    \ ADUG p156 "OSBGET Read Data Byte" [X preserved, Y fileHandle, A ret val]
    LDY fileHandle : JSR osbget : STA byteReadB
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ oneByteFile

    LDY fileHandle : JSR osbget : STA byteReadC
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ twoByteFile

.readContentsLoop
    LDY fileHandle : JSR osbget
    LDX byteReadB : STX byteReadA \ Shuffle B -> A
    LDX byteReadC : STX byteReadB \         C -> B
    STA byteReadC \ Store new byte in C

    LDA bytesToSkip : BNE skipCheck
    LDY byteReadC : LDX byteReadB : LDA byteReadA
    JSR checkBytes : STA bytesToSkip
.skipCheck
    DEC bytesToSkip

    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BNE readContentsLoop

    LDA bytesToSkip : BEQ twoByteFile \ strangely twoByteFile code for now works fine!
\ oneByteFile - TODO zeroByteFile
    LDA byteReadC : LDX #&FF : LDY #&FF
    JSR checkBytes
    \JSR printMessagesFromFlags Chris TODO restore
    JMP closeFile

.zeroByteFile
    LDA #3 \ error 3
    JSR printError
    JMP closeFile

.oneByteFile
    LDA byteReadB : LDX #&FF : LDY #&FF
    JSR checkBytes
    \JSR printMessagesFromFlags Chris TODO restore
    JMP closeFile

.twoByteFile
    LDA byteReadB : LDX byteReadC : LDY #&FF
    JSR checkBytes
    CMP #2 : BEQ bothBytesRead
    LDA byteReadC : LDX #&FF : LDY #&FF
    JSR checkBytes
.bothBytesRead
    \JSR printMessagesFromFlags Chris TODO restore
    \ fall through to closeFile
.closeFile
    LDA #0 \ Close
    LDY fileHandle
    JSR osfind
    RTS

.checkBytes \ given bytes in A/X/Y, return with count of bytes parsed in A
    \ Check for Unix LF line endings
    CMP #ASCII_LF
    BNE checkBeebDos
    LDA #FLAGS_UNIX_LE
    JMP setFlagsAndReturnSingle
.checkBeebDos
    \ Check for Beeb CR or DOS CRLF line endings
    CMP #ASCII_CR
    BNE checkBytesU
    TXA \ check second byte
    CMP #ASCII_LF
    BNE storeBeeb
    LDA #FLAGS_DOS_LE
    JMP setFlagsAndReturnDouble
.storeBeeb
    LDA #FLAGS_BEEB_LE
    JMP setFlagsAndReturnSingle

\ TODO copy across unit tests
.checkBytesU
    STA buffer
    AND #&80 : BEQ ascii
    LDA buffer
    AND #&E0 : CMP #&C0 : BEQ utfDoubleCheckSecondByte
    LDA buffer
    AND #&F0 : CMP #&E0 : BEQ utfTripleCheckSecondByte
    JMP binary
.utfTripleCheckSecondByte
    TXA
    AND #&C0 : CMP #&80 : BEQ utfTripleCheckThirdByte
    JMP binary
.utfTripleCheckThirdByte
    TYA
    AND #&C0 : CMP #&80 : BEQ utfTriple
    JMP binary
.utfDoubleCheckSecondByte
    TXA
    AND #&C0 : CMP #&80 : BEQ utfDouble
    \ fall through to binary
.binary
    LDA #FLAGS_BINARY
    JMP setFlagsAndReturnSingle
.utfTriple
    \                                    BBBB    BBBBAA    AAAAAA
    \ U+20AC = 00100000 10101100 -> 1110-0010 10-000010 10-101100 = &E2, &82, &AC
    \ First byte in buffer
    \ Second/third byte in X/Y
    LDA buffer
    ASL A:ASL A:ASL A:ASL A
    STA buffer \ bits 4-7
    TXA
    LSR A : LSR A
    AND #&F    \ bits 0-3
    ORA buffer
    STA utf16+1

    TXA \ TODO macroify at least?
    ASL A:ASL A:ASL A:ASL A:ASL A:ASL A
    STA buffer \ bits 6-7
    TYA
    AND #&3F   \ bits 0-5
    ORA buffer
    STA utf16

    JSR printUnicode
    LDA #FLAGS_UTF8_TRIPLE
    JMP setFlagsAndReturnTriple
.utfDouble
    \                                   BBBAA    AAAAAA
    \ U+0411 = 00000100 00010001 -> 110-10000 10-010001 = &D0, &91
    \ First byte in buffer
    \ Second byte in X
    LDA buffer
    LSR A : LSR A
    AND #&07   \ bits 8-10
    STA utf16+1
    LDA buffer
    ASL A:ASL A:ASL A:ASL A:ASL A:ASL A
    STA buffer \ bits 6-7
    TXA
    AND #&3F   \ bits 0-5
    ORA buffer
    STA utf16
    JSR printUnicode
    LDA #FLAGS_UTF8_DOUBLE
    JMP setFlagsAndReturnDouble
.ascii
    LDA buffer : JSR printAscii
    LDA #FLAGS_ASCII
    JMP setFlagsAndReturnSingle

.setFlagsAndReturnSingle
    ORA flags : STA flags : LDA #1
    RTS
.setFlagsAndReturnDouble
    ORA flags : STA flags : LDA #2
    RTS
.setFlagsAndReturnTriple
    ORA flags : STA flags : LDA #3
    RTS

.printMessagesFromFlags
    LDX flags
    LDY #8 \ bits in a byte
.printMessageLoop
    TXA : AND #1 : BEQ doneMessage
    JSR messageToPrint
.doneMessage
    TXA : LSR A : TAX
    DEY : BEQ printMessageDone
    JMP printMessageLoop
.printMessageDone
    RTS

MACRO CALC_PTR block
    ASL A : TAY                \ Double index to get offset within block
    LDA block,Y : STA tempPtrL \ Copy appropriate pointer from block into zero page
    INY : LDA block,Y : STA tempPtrH
ENDMACRO

.messageToPrint \ needs to preserve X and Y
    DEY : TYA : PHA \ Preserve Y-1 and move from 1-indexed to 0-indexed
        CALC_PTR flagBlock
        JSR printString
    PLA : TAY : INY \ Restore Y
    RTS

.printError
    TAY : DEY : TYA  \ Move from 1-indexed to 0-indexed
    CALC_PTR errorBlock
.printString \ Also called elsewhere
    LDY #0
.printStringLoop
    LDA (tempPtrL),Y
    JSR oswrch
    CMP #&D : BEQ printStringDone
    INY
    JMP printStringLoop
.printStringDone
    RTS

\ TODO newline chars
.printAscii
    \ U+0027 straight apostrophe
    CMP #&27 : BEQ printUsingUnicode
    \ U+0060 grave accent
    CMP #&60 : BEQ printUsingUnicode
    \ U+007C vertical bar
    CMP #&7C : BEQ printUsingUnicode
    JMP oswrch
    \ implied RTS
.printUsingUnicode
    STA utf16
    LDA #0 : STA utf16+1
    JMP printUnicode
    \ implied RTS

.printUnicode
    \0 print X
    \1 print first character
    \2 put first character in slot then print
    \3 put right character in slot then print (details in utf16 and utf16+1)
    JSR isCharAlreadyDefined
    CMP #0 : BNE printAndReturn \ A contains char to print
    JSR loadCharDefinition \ X contains slot offset
    CMP #0 : BNE printAndReturn \ A contains char to print
    LDA #'X'
.printAndReturn
    JSR oswrch
    \4 put right character in free slot then print
    \5 check if character is in slot beforehand!
    RTS

.isCharAlreadyDefined \ char in utf16 (2 bytes), returns char to print or 0, in which case X is slot offset
    LDA #charSlots MOD 256 : STA tempPtrL
    LDA #charSlots DIV 256 : STA tempPtrH
    LDY #0
    JMP isCharInSlot
.nextSlotTwoBytes
    INY
.nextSlotOneByte
    INY
.isCharInSlot
    LDA (tempPtrL),Y : BEQ slotFirstByteZero
    CMP #&FF : BEQ slotFirstByteFF
.compareBytes
    CMP utf16 : BNE nextSlotTwoBytes
    INY : LDA (tempPtrL),Y : CMP utf16+1 : BNE nextSlotOneByte
    DEY : TYA : LSR A \ Y is double the index plus one
    CLC : ADC #CUSTOM_CHAR_START
    RTS
.slotFirstByteZero
    INY : LDA (tempPtrL),Y : BEQ exhaustedSlots
    LDA #0 : JMP compareBytes
.slotFirstByteFF
    INY : LDA (tempPtrL),Y : CMP #&FF : BEQ foundEmptySlot
    LDA #&FF : JMP compareBytes
.exhaustedSlots \ char not defined
    LDX #0
    LDA #0
    RTS
.foundEmptySlot \ char not defined
    DEY : TYA : TAX
    LDA #0
    RTS

.loadCharDefinition
    LDA #charDefinitions MOD 256 : STA tempPtrL
    LDA #charDefinitions DIV 256 : STA tempPtrH
    JMP checkCharLit
.charLitZero \ check if charBig also zero, if so we have reached the end
    LDY #1 : LDA (tempPtrL),Y : BEQ bothZero
    CMP utf16,Y : BNE nextChar
    JMP bothMatch
.bothZero
    LDA #0 \ failure
    RTS
.nextChar
    CLC
    LDA tempPtrL : ADC #10 : STA tempPtrL
    LDA tempPtrH : ADC #0 : STA tempPtrH
.checkCharLit
    LDY #0 : LDA (tempPtrL),Y : BEQ charLitZero
    CMP utf16,Y : BNE nextChar
    LDY #1 : LDA (tempPtrL),Y : CMP utf16,Y : BNE nextChar
.bothMatch
    \ X passed in as slot offset
    LDY #0
    LDA (tempPtrL),Y : STA charSlots,X : INX : INY
    LDA (tempPtrL),Y : STA charSlots,X : INY
    LDA #&17 : JSR oswrch
    DEX : TXA : LSR A \ X is double the index plus one
    CLC : ADC #CUSTOM_CHAR_START : JSR oswrch
    TAX \ current value of A needs to be returned so save it
.charPrintLoop
    LDA (tempPtrL),Y : JSR oswrch
    INY : CPY #10
    BNE charPrintLoop
    TXA
    RTS

.osfsc
    JMP (&21E)

.errorBlock
    EQUW error1
    EQUW error2
    EQUW error3
    EQUW error4
.error1 EQUS "No parameter supplied", &D
.error2 EQUS "File not found", &D
.error3 EQUS "File is 0 length", &D
.error4 EQUS "Error4", &D

.flagBlock
    EQUW flag1
    EQUW flag2
    EQUW flag3
    EQUW flag4
    EQUW flag5
    EQUW flag6
    EQUW flag7
    EQUW flag8
.flag1 EQUS "Chris message binary", &D
.flag2 EQUS "UTF8QUAD", &D
.flag3 EQUS "UTF8TRIPLE", &D
.flag4 EQUS "UTF8DOUBLE", &D
.flag5 EQUS "Chris message ascii", &D
.flag6 EQUS "DOS line endings", &D
.flag7 EQUS "BBC line endings", &D
.flag8 EQUS "Unix line endings", &D

.charSlots \ 32 slots to define (0xe0 to 0xff)
    EQUW &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF 
    EQUW &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF 
    EQUW 0 \ end marker
.charSlotsEnd

.charDefinitions
    EQUW &27 \ apostrophe
    EQUB &18, &18, &18, &00, &00, &00, &00, &00
    EQUW &60 \ grave accent
    EQUB &30, &18, &00, &00, &00, &00, &00, &00
    EQUW &7C \ vertical line
    EQUB &18, &18, &18, &18, &18, &18, &18, &00

    \ TODO &A0 nbsp

    EQUW &A1
    EQUB &18, &00, &18, &18, &18, &18, &18, &00
    EQUW &A2
    EQUB &08, &3E, &6B, &68, &6B, &3E, &08, &00
    EQUW &A3
    EQUB &1C, &36, &30, &7C, &30, &30, &7E, &00
    EQUW &A4
    EQUB &00, &66, &3C, &66, &66, &3C, &66, &00
    EQUW &A5
    EQUB &66, &3C, &18, &18, &7E, &18, &18, &00
    EQUW &A6
    EQUB &18, &18, &18, &00, &18, &18, &18, &00
    EQUW &A7
    EQUB &3C, &60, &3C, &66, &3C, &06, &3C, &00
    EQUW &A8
    EQUB &66, &00, &00, &00, &00, &00, &00, &00
    EQUW &A9
    EQUB &3C, &42, &99, &A1, &A1, &99, &42, &3C
    EQUW &AA
    EQUB &1C, &06, &1E, &36, &1E, &00, &3E, &00
    EQUW &AB
    EQUB &00, &33, &66, &CC, &CC, &66, &33, &00
    EQUW &AC
    EQUB &7E, &06, &00, &00, &00, &00, &00, &00

    \ TODO &AD shy

    EQUW &AE
    EQUB &3C, &42, &B9, &A5, &B9, &A5, &42, &3C
    EQUW &AF
    EQUB &7E, &00, &00, &00, &00, &00, &00, &00

    EQUW &B0
    EQUB &3C, &66, &3C, &00, &00, &00, &00, &00
    EQUW &B1
    EQUB &18, &18, &7E, &18, &18, &00, &7E, &00
    EQUW &B2
    EQUB &38, &04, &18, &20, &3C, &00, &00, &00
    EQUW &B3
    EQUB &38, &04, &18, &04, &38, &00, &00, &00
    EQUW &B4
    EQUB &0C, &18, &00, &00, &00, &00, &00, &00
    EQUW &B5
    EQUB &00, &00, &33, &33, &33, &33, &3E, &60
    EQUW &B6
    EQUB &03, &3E, &76, &76, &36, &36, &3E, &00
    EQUW &B7
    EQUB &00, &00, &00, &18, &18, &00, &00, &00
    EQUW &B8
    EQUB &00, &00, &00, &00, &00, &00, &18, &30
    EQUW &B9
    EQUB &10, &30, &10, &10, &38, &00, &00, &00
    EQUW &BA
    EQUB &1C, &36, &36, &36, &1C, &00, &3E, &00
    EQUW &BB
    EQUB &00, &CC, &66, &33, &33, &66, &CC, &00
    EQUW &BC
    EQUB &40, &C0, &40, &48, &48, &0A, &0F, &02
    EQUW &BD
    EQUB &40, &C0, &40, &4F, &41, &0F, &08, &0F
    EQUW &BE
    EQUB &E0, &20, &E0, &28, &E8, &0A, &0F, &02
    EQUW &BF
    EQUB &18, &00, &18, &18, &30, &66, &3C, &00

    EQUW &E0
    EQUB &30, &18, &3C, &06, &3E, &66, &3E, &00
    EQUW &E1
    EQUB &0C, &18, &3C, &06, &3E, &66, &3E, &00
    EQUW &E2
    EQUB &18, &66, &3C, &06, &3E, &66, &3E, &00
    EQUW &E3
    EQUB &36, &6C, &3C, &06, &3E, &66, &3E, &00
    EQUW &E4
    EQUB &66, &00, &3C, &06, &3E, &66, &3E, &00
    EQUW &E5
    EQUB &3C, &66, &3C, &06, &3E, &66, &3E, &00
    EQUW &E6
    EQUB &00, &00, &3F, &0D, &3F, &6C, &3F, &00
    EQUW &E7
    EQUB &00, &00, &3C, &66, &60, &66, &3C, &60
    EQUW &E8
    EQUB &30, &18, &3C, &66, &7E, &60, &3C, &00
    EQUW &E9
    EQUB &0C, &18, &3C, &66, &7E, &60, &3C, &00
    EQUW &EA
    EQUB &3C, &66, &3C, &66, &7E, &60, &3C, &00
    EQUW &EB
    EQUB &66, &00, &3C, &66, &7E, &60, &3C, &00
    EQUW &EC
    EQUB &30, &18, &00, &38, &18, &18, &3C, &00
    EQUW &ED
    EQUB &0C, &18, &00, &38, &18, &18, &3C, &00
    EQUW &EE
    EQUB &3C, &66, &00, &38, &18, &18, &3C, &00
    EQUW &EF
    EQUB &66, &00, &38, &18, &18, &18, &3C, &00
    EQUW &F0
    EQUB &18, &3E, &0C, &06, &3E, &66, &3E, &00
    EQUW &F1
    EQUB &36, &6C, &00, &7C, &66, &66, &66, &00
    EQUW &F2
    EQUB &30, &18, &00, &3C, &66, &66, &3C, &00
    EQUW &F3
    EQUB &0C, &18, &00, &3C, &66, &66, &3C, &00
    EQUW &F4
    EQUB &3C, &66, &00, &3C, &66, &66, &3C, &00
    EQUW &F5
    EQUB &36, &6C, &00, &3C, &66, &66, &3C, &00
    EQUW &F6
    EQUB &66, &00, &00, &3C, &66, &66, &3C, &00
    EQUW &F7
    EQUB &00, &18, &00, &FF, &00, &18, &00, &00
    EQUW &F8
    EQUB &00, &02, &3C, &6E, &76, &66, &BC, &00
    EQUW &F9
    EQUB &30, &18, &66, &66, &66, &66, &3E, &00
    EQUW &FA
    EQUB &0C, &18, &66, &66, &66, &66, &3E, &00
    EQUW &FB
    EQUB &3C, &66, &00, &66, &66, &66, &3E, &00
    EQUW &FC
    EQUB &66, &00, &66, &66, &66, &66, &3E, &00
    EQUW &FD
    EQUB &0C, &18, &66, &66, &66, &3E, &06, &3C
    EQUW &FE
    EQUB &60, &60, &7C, &66, &7C, &60, &60, &00
    EQUW &FF
    EQUB &66, &00, &66, &66, &66, &3E, &06, &3C

    EQUW &20AC \ euro
    EQUB &3C, &66, &60, &F8, &60, &66, &3C, &00
    EQUW 0 \ end marker
.charDefinitionsEnd
