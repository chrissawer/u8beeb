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
.controlBlock EQUD 0 \ must be 4 bytes in zero page for osargs
.utf16        EQUW 0
.tempPtrL     EQUB 0
.tempPtrH     EQUB 0
.fileHandle   EQUB 0
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

    LDA #7 : LDX #7 : JSR osbyte \ 9600 receive
    LDA #8 : LDX #7 : JSR osbyte \ 9600 transmit
    LDA #2 : LDX #2 : JSR osbyte \ enable RS423 input
    LDA #&15 : LDX #1 : JSR osbyte \ flush RS423 input

.checkKeyboard
    LDA #&80 : LDX #&FF : JSR osbyte \ check keyboard buffer
    CPX #0 : BEQ checkSerial
    LDA #&91 : LDX #0 : JSR osbyte \ get byte from keyboard buffer
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

.single
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

.readByteBlocking \ blocks, returns byte in Y
    LDA #&91 : LDX #1 : JSR osbyte
    BCS readByteBlocking
    RTS

INCLUDE "../utf8core.asm"
INCLUDE "../charDefinitions.asm"

.end

SAVE "u8ser", start, end
