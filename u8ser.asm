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
    LDA #'!' : JSR oswrch \ TODO debug
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
    JSR readByteBlocking
    LDX #4 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    JSR readByteBlocking
    LDX #5 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    JMP esc5bCheckForUnwind

.esc5bPairMid \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
.esc5bPairMidSkip
    JMP esc5bNextPair

.esc5bPairFinal \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
    CPY #'m' : BEQ esc5bColourList
    CPY #'H' : BEQ esc5bCursorPosition
    CPY #'J' : BEQ esc5bEraseInDisplay
    CPY #'K' : BEQ esc5bEraseInLine
    LDA #'$' : JSR oswrch \ TODO debug
    TYA : JSR oswrch \ TODO debug unhandled code between dollar signs
.esc5bPairFinalSkip
.esc5bCheckForUnwind
    LDA flags : BEQ esc5bErrorUnwindLoopDone
.esc5bErrorUnwindLoop
    LDA #'$' : JSR oswrch \ TODO debug
    PLA : DEC flags : BNE esc5bErrorUnwindLoop
.esc5bErrorUnwindLoopDone
    JMP checkKeyboard

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

.esc5bColourList
    JMP esc5bColourListJmp
.esc5bCursorPosition
    JMP esc5bCursorPositionJmp
.esc5bEraseInDisplay
    JMP esc5bEraseInDisplayJmp
.esc5bEraseInLine
    JMP esc5bEraseInLineJmp

.esc5bCursorPositionJmp
    LDA flags : CMP #1 : BNE cursorPositionTwoFlagsOnStack
    LDA #0 : PHA : INC flags \ push default 0 onto the stack
.cursorPositionTwoFlagsOnStack
    LDA #31 : JSR oswrch \ VDU 31
    DEC flags : PLA : BEQ cursorPositionFirstIsZero
    SEC : SBC #1 \ move from 1-based to 0-based
.cursorPositionFirstIsZero
    JSR oswrch
    DEC flags : PLA : BEQ cursorPositionSecondIsZero
    SEC : SBC #1 \ move from 1-based to 0-based
.cursorPositionSecondIsZero
    JSR oswrch
    JMP esc5bCheckForUnwind

.esc5bEraseInDisplayJmp
    DEC flags : PLA
    \ TODO 0/missing
    CMP #1 : BEQ esc5bEraseInDisplaySOS
    CMP #2 : BEQ esc5bEraseInDisplayFull
    CMP #3 : BEQ esc5bEraseInDisplayFull
    JMP esc5bCheckForUnwind

.esc5bEraseInDisplaySOS
    LDA #&86 : JSR osbyte \ read cursor position
    TYA : BEQ esc5bEraseInLineSOL \ handle Y=0
    PHA \ save Y position on stack
    TXA : PHA \ save X position on stack

    LDA #31 : JSR oswrch \ VDU 31 - move cursor
    LDA #0 : JSR oswrch : JSR oswrch \ (0, 0)
    LDA #' '
.esc5bEraseInDisplaySOSOuterLoop
    LDX #80 \ TODO should not be hardcoded
.esc5bEraseInDisplaySOSInnerLoop
    JSR oswrch : DEX : BNE esc5bEraseInDisplaySOSInnerLoop
    DEY : BNE esc5bEraseInDisplaySOSOuterLoop

    PLA : TAX \ restore X position
    PLA : TAY \ restore Y position
    JMP esc5bEraseInLineSOL

.esc5bEraseInDisplayFull
    LDA #12 : JSR oswrch \ VDU 12
    JMP esc5bCheckForUnwind

.esc5bEraseInLineJmp
    LDA #&86 : JSR osbyte \ all three variants read cursor position
    DEC flags : PLA
    CMP #0 : BEQ esc5bEraseInLineEOL
    CMP #1 : BEQ esc5bEraseInLineSOL
    CMP #2 : BEQ esc5bEraseInLineFull
    JMP esc5bCheckForUnwind

.esc5bEraseInLineSOL
    LDA #31 : JSR oswrch \ VDU 31 - move to start of line
    LDA #0 : JSR oswrch
    TYA : JSR oswrch
    LDA #' '
.esc5bEraseInLineSOLLoop
    JSR oswrch
    DEX : BNE esc5bEraseInLineSOLLoop
    JMP esc5bCheckForUnwind

.esc5bEraseInLineEOL
    TYA : PHA : TXA : PHA \ store cursor position
    TXA : EOR #&FF : CLC : ADC #81 \ calculate number of spaces
    \ TODO 80 should not be hardcoded
    TAY
    JMP esc5bEraseInLineGo

.esc5bEraseInLineFull
    TYA : PHA : TXA : PHA \ store cursor position
    LDA #31 : JSR oswrch \ VDU 31 - move to start of line
    LDA #0 : JSR oswrch
    TYA : JSR oswrch
    LDY #80
    \ TODO 80 should not be hardcoded
.esc5bEraseInLineGo
    \ Cursor position to restore on stack, number of spaces in Y
    LDA #' '
.esc5bEraseInLineLoop
    JSR oswrch
    DEY : BNE esc5bEraseInLineLoop
    LDA #31 : JSR oswrch \ VDU 31 - restore cursor position
    PLA : JSR oswrch
    PLA : JSR oswrch
    JMP esc5bCheckForUnwind

.esc5bColourListJmp
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
