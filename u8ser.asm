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
    CMP #5 : BEQ esc

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

.nonPrint
    CPY #&0D : BEQ print
    JMP checkKeyboard

.print
    TYA : JSR osasci
    JMP checkKeyboard

.esc
    JSR readByteBlocking
    CPY #&5B : BEQ esc5b
    TYA : JSR checkBytes \ if not 5b, print it and give up for now!
    JMP checkKeyboard

.esc5b \ sequences of ASCII numbers (up to 3 digits) separated by a semicolon
    LDA #0: STA flags \ use flags for stack count
.esc5bNextPair
    LDA #0: STA byteReadA : STA byteReadB : STA byteReadC
    JSR readByteBlocking
    LDX #0 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadA
    JSR readByteBlocking
    LDX #1 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadB
    JSR readByteBlocking
    LDX #2 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadC
    JSR readByteBlocking
    LDX #3 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    JMP esc5bErrorUnwind

.esc5bPairHandle \ X contains number of characters read
    CPX #0 : BEQ esc5bZero
    CPX #1 : BEQ esc5bOne
    CPX #2 : BEQ esc5bTwo
    RTS
.esc5bTwo
    LDA byteReadB
    SEC : SBC #'0' : STA byteReadB \ trash prev
    LDA byteReadA
    SEC : SBC #'0'
    ASL A : STA byteReadA \ trash prev
    ASL A : ASL A
    CLC : ADC byteReadA \ crude x10
    ADC byteReadB
    RTS
.esc5bOne
    LDA byteReadA
    SEC : SBC #'0'
    RTS
.esc5bZero
    LDA #0 \ Default to zero if no characters
    RTS

.esc5bPairMid \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
.esc5bPairMidSkip
    JMP esc5bNextPair

.esc5bPairFinal \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
    CPY #'m' : BEQ esc5bColourList
    CPY #'J' : BEQ esc5bEraseInDisplay
    LDA #'$' : JSR oswrch \ TODO debug
    TYA : JSR oswrch \ TODO debug unhandled code between dollar signs
.esc5bPairFinalSkip
.esc5bErrorUnwind
    LDA #'$' : JSR oswrch \ TODO debug
    LDA flags : BEQ esc5bErrorUnwindLoopDone
.esc5bErrorUnwindLoop
    PLA : DEC flags : BNE esc5bErrorUnwindLoop
.esc5bErrorUnwindLoopDone
    JMP checkKeyboard

.esc5bEraseInDisplay
.esc5bEraseInDisplayLoop
    PLA : JSR esc5bEraseInDisplaySwitch
    DEC flags : BNE esc5bEraseInDisplayLoop
    JMP checkKeyboard

.esc5bEraseInDisplaySwitch
    \ TODO 0/missing
    \ TODO 1
    CMP #2 : BEQ esc5bEraseInDisplayFull
    CMP #3 : BEQ esc5bEraseInDisplayFull
    RTS
.esc5bEraseInDisplayFull
    LDA #12 : JSR oswrch \ VDU 12
    RTS

.esc5bColourList
.esc5bColourListLoop \ flags will never be zero
    PLA : JSR esc5bColour
    DEC flags : BNE esc5bColourListLoop
    JMP checkKeyboard

.esc5bColour
    TAX : SEC : SBC #48 : BPL esc5bColourDone \ not a colour
    TXA : SEC : SBC #40 : BPL esc5bColourBg
    TXA : SEC : SBC #38 : BPL esc5bColourDone \ not a colour
    TXA : SEC : SBC #30 : BPL esc5bColourFg
    CPX #0 : BEQ esc5bColourReset
    CPX #7 : BEQ esc5bColourInvert
    JMP esc5bColourDone
.esc5bColourReset
    LDA #17 : JSR oswrch : LDA #7 : JSR oswrch   \ white fg
    LDA #17 : JSR oswrch : LDA #128 : JSR oswrch \ black bg
    JMP esc5bColourDone
.esc5bColourInvert
    LDA #17 : JSR oswrch : LDA #0 : JSR oswrch   \ black fg
    LDA #17 : JSR oswrch : LDA #135 : JSR oswrch \ white bg
    JMP esc5bColourDone
.esc5bColourFg
    LDA #17 : JSR oswrch
    TXA : SEC : SBC #30 : JSR oswrch \ ANSI 30-37 -> Beeb 0-7
    JMP esc5bColourDone
.esc5bColourBg
    LDA #17 : JSR oswrch
    TXA : CLC : ADC #88 : JSR oswrch \ ANSI 40-47 -> Beeb 128-135
.esc5bColourDone
    RTS

.readByteBlocking \ blocks, returns byte in Y
    LDA #&91 : LDX #1 : JSR osbyte
    BCS readByteBlocking
    RTS

INCLUDE "../utf8core.asm"
INCLUDE "../charDefinitions.asm"

.end

SAVE "u8ser", start, end
