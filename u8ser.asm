osfind = &FFCE
osbget = &FFD7
osargs = &FFDA
osrdch = &FFE0
osasci = &FFE3
osnewl = &FFE7
oswrch = &FFEE
osbyte = &FFF4

FLAGS_UNIX_LE     =  &1
FLAGS_BEEB_LE     =  &2
FLAGS_DOS_LE      =  &4
FLAGS_ASCII       =  &8
FLAGS_UTF8_DOUBLE = &10
FLAGS_UTF8_TRIPLE = &20
FLAGS_UTF8_QUAD   = &40
FLAGS_BINARY      = &80

ASCII_LF    = &0A
ASCII_CR    = &0D
ASCII_SPACE = &20

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
\ TODO how much of this needs to be in zero page? [&70 - &8f are available]

ORG &2000
.start
    LDA #0
    STA flags
    STA bytesToSkip
    STA nextReuseSlot

    LDA #&E5 : LDX #1 : JSR osbyte \ treat escape key as ascii
    LDA #7 : LDX #7 : JSR osbyte \ 9600 receive
    LDA #8 : LDX #7 : JSR osbyte \ 9600 transmit
    LDA #2 : LDX #2 : JSR osbyte \ enable RS423 input
    LDA #&15 : LDX #1 : JSR osbyte \ flush RS423 input

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

.single
    TYA : AND #&60 : BEQ nonPrint
    TYA : JSR checkBytes
    JMP checkKeyboard

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
    CPY #'D' : BEQ cursorDown
    CPY #'M' : BEQ cursorUp
    CPY #'E' : BEQ cursorNextLine
    CPY #'7' : BEQ cursorSave
    CPY #'8' : BEQ cursorRestore
    CPY #'<' : BEQ ignore \ exit VT52 mode
    CPY #'>' : BEQ ignore \ keypad keys in numeric mode
    CPY #'P' : BEQ dcs
    CPY #'\' : BEQ ignore \ DCS terminate

    \TYA : JSR oswrch \ TODO debug
    LDA #'!' : JSR oswrch \ TODO debug indicates unhandled code
.ignore
    JMP checkKeyboard

.esc5bJump
    JMP esc5b

.nonPrint
    CPY #&08 : BEQ print \ backspace
    CPY #&0A : BEQ print \ line feed
    CPY #&0D : BEQ print \ carriage return
    JMP checkKeyboard

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

.end

SAVE "u8ser", start, end
