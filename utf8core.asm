CUSTOM_CHAR_START = &E0

.checkBytes \ given bytes in A/X/Y, return with count of bytes parsed in A
    \ Check for Unix LF line endings
    CMP #ASCII_LF
    BNE checkBeebDos
    JSR osnewl
    LDA #FLAGS_UNIX_LE
    JMP setFlagsAndReturnSingle
.checkBeebDos
    \ Check for Beeb CR or DOS CRLF line endings
    CMP #ASCII_CR
    BNE checkBytesU
    TXA \ check second byte
    CMP #ASCII_LF
    BNE storeBeeb
    JSR osnewl
    LDA #FLAGS_DOS_LE
    JMP setFlagsAndReturnDouble
.storeBeeb
    JSR osnewl
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
    LDA (tempPtrL),Y
.printStringLoop
    JSR oswrch
    INY
    LDA (tempPtrL),Y
    BNE printStringLoop
    JSR osnewl
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
    LDA #0
    LDX nextReuseSlot
    CPX #62 \ last slot is index 31 (2 bytes each)
    BEQ exhaustedSlotsWrap
    INC nextReuseSlot
    INC nextReuseSlot
    RTS
.exhaustedSlotsWrap
    STA nextReuseSlot \ A = 0
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

.errorBlock
    EQUW error1
    EQUW error2
    EQUW error3
    EQUW error4
.error1 EQUS "No parameter supplied", 0
.error2 EQUS "File not found", 0
.error3 EQUS "File is 0 length", 0
.error4 EQUS "Error4", 0

.flagBlock
    EQUW flag1
    EQUW flag2
    EQUW flag3
    EQUW flag4
    EQUW flag5
    EQUW flag6
    EQUW flag7
    EQUW flag8
.flag1 EQUS "Chris message binary", 0
.flag2 EQUS "UTF8QUAD", 0
.flag3 EQUS "UTF8TRIPLE", 0
.flag4 EQUS "UTF8DOUBLE", 0
.flag5 EQUS "Chris message ascii", 0
.flag6 EQUS "DOS line endings", 0
.flag7 EQUS "BBC line endings", 0
.flag8 EQUS "Unix line endings", 0

.charSlots \ 32 slots to define (0xe0 to 0xff)
    EQUW &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF 
    EQUW &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF, &FFFF 
    EQUW 0 \ end marker
.charSlotsEnd
