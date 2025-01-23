INCLUDE "../commonDefinitions.asm"

ORG &70
\ NOTE these are not auto-initialised!
.utf16        EQUW 0
.tempPtrL     EQUB 0
.tempPtrH     EQUB 0
.cursorX      EQUB 0
.cursorY      EQUB 0
.byteReadA    EQUB 0
.byteReadB    EQUB 0
.byteReadC    EQUB 0
.flags        EQUB 0
.buffer       EQUB 0 \ TODO
.bytesToSkip  EQUB 0
.nextReuseSlot EQUB 0
.charSetFlags  EQUB 0
\ TODO how much of this needs to be in zero page? [&70 - &8f are available]

ORG &2000
.start
    LDA #0
    STA flags
    STA bytesToSkip
    STA nextReuseSlot
    STA charSetFlags

    LDA #&E5 : LDX #1 : JSR osbyte \ treat escape key as ascii
    LDA #7 : LDX #7 : JSR osbyte \ 9600 receive
    LDA #8 : LDX #7 : JSR osbyte \ 9600 transmit
    LDA #2 : LDX #2 : JSR osbyte \ enable RS423 input
    LDA #&15 : LDX #1 : JSR osbyte \ flush RS423 input
    JMP checkKeyboard

.nonAsciiUp
    LDA #&41 \ A
    JMP sendAnsi
.nonAsciiDown
    LDA #&42 \ B
    JMP sendAnsi
.nonAsciiRight
    LDA #&43 \ C
    JMP sendAnsi
.nonAsciiLeft
    LDA #&44 \ D
    \JMP sendAnsi \ fall through
.sendAnsi
    PHA
    LDA #&8A : LDX #2
    LDY #&1B : JSR osbyte \ ESC
    LDY #&5B : JSR osbyte \ [
    PLA : TAY : LDA #&8A : JSR osbyte
    JMP checkSerial

.checkKeyboard
    LDA #&80 : LDX #&FF : JSR osbyte \ check keyboard buffer
    CPX #0 : BEQ checkSerial
    LDA #&91 : LDX #0 : JSR osbyte \ get byte from keyboard buffer

    TYA : AND #&80 : BNE nonAscii \ arrow key or copy
    LDA #&8A : LDX #2 : JSR osbyte \ put into RS423 output buffer
.checkSerial
    LDA #&80 : LDX #&FE : JSR osbyte \ check RS423 input buffer
    CPX #0 : BEQ checkKeyboard \ no bytes read

    LDA #&91 : LDX #1 : JSR osbyte \ get byte from RS423 input buffer
    TYA : JSR howManyBytes
    CMP #1 : BEQ single
    CMP #2 : BEQ double
    CMP #3 : BEQ triple
    CMP #4 : BEQ quad
    CMP #5 : BEQ esc

.nonAscii
    \ Y has the Beeb key
    CPY #&8F : BEQ nonAsciiUp
    CPY #&8E : BEQ nonAsciiDown
    CPY #&8D : BEQ nonAsciiRight
    CPY #&8C : BEQ nonAsciiLeft
    JMP checkSerial

.single
    TYA : AND #&60 : BEQ nonPrint
    LDA charSetFlags : BEQ notBoxMode
.boxMode
    CPY #&60 : BPL boxModeByteJump
.notBoxMode
    TYA : JSR checkBytes
    JMP checkKeyboard

.boxModeByteJump
    JMP boxModeByte

.double
    STY byteReadA : JSR readByteBlocking
    TYA : TAX : LDA byteReadA : JSR checkBytes
    JMP checkKeyboard

.triple
    STY byteReadA : JSR readByteBlocking
    STY byteReadB : JSR readByteBlocking
    LDA byteReadA : LDX byteReadB : JSR checkBytes
    JMP checkKeyboard

.quad
    JSR readByteBlocking
    JSR readByteBlocking
    JSR readByteBlocking
    JMP checkKeyboard

.esc
    JSR readByteBlocking
    CPY #&5B : BEQ esc5bJump
    CPY #'D' : BEQ cursorDownJump
    CPY #'M' : BEQ cursorUpJump
    CPY #'E' : BEQ cursorNextLineJump
    CPY #'7' : BEQ cursorSaveJump
    CPY #'8' : BEQ cursorRestoreJump
    CPY #'<' : BEQ ignore \ exit VT52 mode
    CPY #'>' : BEQ ignore \ keypad keys in numeric mode
    CPY #'P' : BEQ dcsJump
    CPY #'\' : BEQ ignore \ DCS terminate

    \TYA : JSR oswrch \ TODO debug
    LDA #'!' : JSR oswrch \ TODO debug indicates unhandled code
.ignore
    JMP checkKeyboard

.nonPrint
    CPY #&08 : BEQ print \ backspace
    CPY #&0A : BEQ print \ line feed
    CPY #&0D : BEQ print \ carriage return
    CPY #&0E : BEQ switchToG1Jump
    CPY #&0F : BEQ switchToG0Jump
    JMP checkKeyboard

.boxModeByte
    TYA : SEC : SBC #&60 : ASL A : TAY \ gives offset into table
    LDA boxMappings,Y : STA utf16
    INY : LDA boxMappings,Y : STA utf16+1
    JSR printUnicode
    JMP checkKeyboard

.esc5bJump
    JMP esc5b
.cursorDownJump
    JMP cursorDown
.cursorUpJump
    JMP cursorUp
.cursorNextLineJump
    JMP cursorNextLine
.cursorSaveJump
    JMP cursorSave
.cursorRestoreJump
    JMP cursorRestore
.dcsJump
    JMP dcs
.switchToG1Jump
    JMP switchToG1
.switchToG0Jump
    JMP switchToG0

.print
    TYA : JSR oswrch
    JMP checkKeyboard

.cursorDown
    LDA #10: JSR oswrch \ VDU 10 - cursor down (LF)
    JMP checkKeyboard

.cursorUp
    LDA #11: JSR oswrch \ VDU 11 - cursor up
    JMP checkKeyboard

.cursorNextLine
    LDA #13: JSR oswrch \ VDU 13 - CR
    LDA #10: JSR oswrch \ VDU 10 - cursor down (LF)
    JMP checkKeyboard

.cursorSave
    LDA #&86 : JSR osbyte \ read cursor position
    STX cursorX
    STY cursorY
    JMP checkKeyboard

.cursorRestore
    LDA #31 : JSR oswrch \ VDU 31 - move cursor
    LDA cursorX : JSR oswrch
    LDA cursorY : JSR oswrch
    JMP checkKeyboard

.dcs
    JSR readByteBlocking
    CPY #'\' : BNE dcs \ should really check it's 1b then \
    JMP checkKeyboard

.switchToG1
    LDA #1 : STA charSetFlags
    JMP checkKeyboard

.switchToG0
    LDA #0 : STA charSetFlags
    JMP checkKeyboard

MACRO GET_NEXT_BYTE
    JSR readByteBlocking
ENDMACRO
MACRO PROCESSING_DONE
    JMP checkKeyboard
ENDMACRO
INCLUDE "../u8ser_esc5b.asm"

.readByteBlocking \ blocks, returns byte in Y
    LDA #&91 : LDX #1 : JSR osbyte
    BCS readByteBlocking
    RTS

INCLUDE "../utf8core.asm"
INCLUDE "../charDefinitions.asm"

.boxMappings
    \ A0 is nbsp for undefined chars
    EQUW &25C6 \ &60
    EQUW &2592 \ &61
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00B0 \ &66
    EQUW &00B1 \ &67
    EQUW &00A0
    EQUW &00A0
    EQUW &2518 \ &6A
    EQUW &2510 \ &6B
    EQUW &250C \ &6C
    EQUW &2514 \ &6D
    EQUW &253C \ &6E
    EQUW &23BA \ &6F
    EQUW &23BB \ &70
    EQUW &2500 \ &71
    EQUW &23BC \ &72
    EQUW &23BD \ &73
    EQUW &251C \ &74
    EQUW &2524 \ &75
    EQUW &2534 \ &76
    EQUW &252C \ &77
    EQUW &2502 \ &78
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0
    EQUW &00A0 \ run to 7f to avoid out of range access

.end

SAVE "u8ser", start, end
