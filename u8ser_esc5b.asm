.esc5b \ sequences of ASCII numbers (up to 3 digits) separated by a semicolon
    LDA #0: STA flags \ use flags for stack count
.esc5bNextPair
    LDA #0: STA byteReadA : STA byteReadB : STA byteReadC
    GET_NEXT_BYTE
    LDX #0 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadA
    GET_NEXT_BYTE
    LDX #1 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadB
    GET_NEXT_BYTE
    LDX #2 : CPY #';' : BEQ esc5bPairMid : TYA : AND #&40 : BNE esc5bPairFinal
    STY byteReadC
    GET_NEXT_BYTE
    LDX #3 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    GET_NEXT_BYTE
    LDX #4 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    GET_NEXT_BYTE
    LDX #5 : CPY #';' : BEQ esc5bPairMidSkip : TYA : AND #&40 : BNE esc5bPairFinalSkip \ not implemented
    JMP esc5bCheckForUnwind

.esc5bPairMid \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
.esc5bPairMidSkip
    JMP esc5bNextPair

.esc5bPairFinal \ X contains number of characters read
    JSR esc5bPairHandle : PHA : INC flags
    CPY #'m' : BEQ esc5bColourList

    CPY #'C' : BEQ esc5bCursorForward
    CPY #'D' : BEQ esc5bCursorBack
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
    PROCESSING_DONE

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
.esc5bCursorForward
    JMP esc5bCursorForwardJmp
.esc5bCursorBack
    JMP esc5bCursorBackJmp
.esc5bCursorPosition
    JMP esc5bCursorPositionJmp
.esc5bEraseInDisplay
    JMP esc5bEraseInDisplayJmp
.esc5bEraseInLine
    JMP esc5bEraseInLineJmp

.esc5bCursorForwardJmp
    LDA #&86 : JSR osbyte \ read cursor position
    DEC flags : PLA
    TAY : BNE esc5bCursorForwardSkip
    LDY #1 \ zero means one
.esc5bCursorForwardSkip
    \ Do not go past the right-hand edge of the screen
    TXA : EOR #&FF \ subtract current X from screen width-1
    CLC : ADC #80 \ TODO hardcoded width
    STA buffer \ have to resort to zero page as can't compare A and Y :-(
    CPY buffer : BMI esc5bCursorForwardLoop \ value in Y is ok - go straight to loop
    TAY : BEQ esc5bCursorForwardDone \ use calculated maximum unless it is 0
.esc5bCursorForwardLoop
    LDA #9 : JSR oswrch \ VDU 9 - cursor forward
    DEY : BNE esc5bCursorForwardLoop
.esc5bCursorForwardDone
    JMP esc5bCheckForUnwind

.esc5bCursorBackJmp
    LDA #&86 : JSR osbyte \ read cursor position
    DEC flags : PLA
    TAY : BNE esc5bCursorBackSkip
    LDY #1 \ zero means one
.esc5bCursorBackSkip
    \ Do not go past the left-hand edge of the screen
    STX buffer \ store current X in zero page
    CPY buffer : BMI esc5bCursorBackLoop \ value in Y is ok - go straight to loop
    LDY buffer : BEQ esc5bCursorBackDone \ use calculated maximum unless it is 0
.esc5bCursorBackLoop
    LDA #8 : JSR oswrch \ VDU 8 - cursor back
    DEY : BNE esc5bCursorBackLoop
.esc5bCursorBackDone
    JMP esc5bCheckForUnwind

.esc5bCursorPositionJmp
    LDA flags : CMP #1 : BNE cursorPositionTwoFlagsOnStack
    LDA #0 : PHA : INC flags \ push default 0 onto the stack
.cursorPositionTwoFlagsOnStack
    LDA #31 : JSR oswrch \ VDU 31 - move cursor
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
    CMP #0 : BEQ esc5bEraseInDisplayEOS
    CMP #1 : BEQ esc5bEraseInDisplaySOS
    CMP #2 : BEQ esc5bEraseInDisplayFull
    CMP #3 : BEQ esc5bEraseInDisplayFull
    JMP esc5bCheckForUnwind

.esc5bEraseInDisplayFull
    LDA #12 : JSR oswrch \ VDU 12 - CLS
    JMP esc5bCheckForUnwind

.esc5bEraseInDisplayEOS
    LDA #&86 : JSR osbyte \ read cursor position
    CPY #31 : BEQ esc5bEraseInDisplayEOSJump \ are we on the bottom line TODO hardcoded height

    TYA : PHA \ save Y position on stack
    TXA : PHA \ save X position on stack
    LDA #31 : JSR oswrch \ VDU 31 - move cursor
    LDA #0 : JSR oswrch : INY : TYA : JSR oswrch \ start of next line

    TYA : EOR #&FF : CLC : ADC #32 : TAY \ calculate number of lines to erase TODO 32 should not be hardcoded
    BEQ esc5bEraseInDisplayEOSBottomLine

    LDA #' '
.esc5bEraseInDisplayEOSOuterLoop
    LDX #80 \ TODO should not be hardcoded
.esc5bEraseInDisplayEOSInnerLoop
    JSR oswrch : DEX : BNE esc5bEraseInDisplayEOSInnerLoop
    DEY : BNE esc5bEraseInDisplayEOSOuterLoop

.esc5bEraseInDisplayEOSBottomLine
    LDA #' '
    LDX #79 \ TODO should not be hardcoded
.esc5bEraseInDisplayEOS2ndLoop
    JSR oswrch : DEX : BNE esc5bEraseInDisplayEOS2ndLoop

    LDA #31 : JSR oswrch \ VDU 31 - move cursor
    PLA : TAX \ restore X position
    JSR oswrch
    PLA : TAY \ restore Y position
    JSR oswrch
.esc5bEraseInDisplayEOSJump
    JMP esc5bEraseInLineEOL

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

.esc5bEraseInLineJmp
    LDA #&86 : JSR osbyte \ all three variants read cursor position
    DEC flags : PLA
    CMP #0 : BEQ esc5bEraseInLineEOL
    CMP #1 : BEQ esc5bEraseInLineSOL
    CMP #2 : BEQ esc5bEraseInLineFull
    JMP esc5bCheckForUnwind

.esc5bEraseInLineSOL
    CPX #0 : BEQ esc5bEraseInLineSOLSkip \ first column - nothing to do
    LDA #31 : JSR oswrch \ VDU 31 - move to start of line
    LDA #0 : JSR oswrch
    TYA : JSR oswrch
    LDA #' '
.esc5bEraseInLineSOLLoop
    JSR oswrch
    DEX : BNE esc5bEraseInLineSOLLoop
.esc5bEraseInLineSOLSkip
    JMP esc5bCheckForUnwind

.esc5bEraseInLineEOL
    TYA : PHA : TXA : PHA \ store cursor position
    TXA : EOR #&FF : CLC : ADC #81 \ calculate number of spaces
    \ TODO 80 and 32 should not be hardcoded
    CPY #31 : BNE esc5bEraseInLineEOLSkip
    CMP #1 : BEQ esc5bEraseInLineRestoreCursor \ bottom right corner
    SEC : SBC #1 \ bottom row, draw one less space to avoid wrap
.esc5bEraseInLineEOLSkip
    TAY
    JMP esc5bEraseInLineGo

.esc5bEraseInLineFull
    TYA : PHA : TXA : PHA \ store cursor position
    LDA #31 : JSR oswrch \ VDU 31 - move to start of line
    LDA #0 : JSR oswrch
    TYA : JSR oswrch
    LDY #80
    CMP #31 : BNE esc5bEraseInLineGo
    LDY #79 \ bottom row, draw one less space to avoid wrap
    \ TODO 80/79 and 32 should not be hardcoded
.esc5bEraseInLineGo
    \ Cursor position to restore on stack, number of spaces in Y
    LDA #' '
.esc5bEraseInLineLoop
    JSR oswrch
    DEY : BNE esc5bEraseInLineLoop
.esc5bEraseInLineRestoreCursor
    LDA #31 : JSR oswrch \ VDU 31 - restore cursor position
    PLA : JSR oswrch
    PLA : JSR oswrch
    JMP esc5bCheckForUnwind

.esc5bColourListJmp
.esc5bColourListLoop \ flags will never be zero
    PLA : JSR esc5bColour
    DEC flags : BNE esc5bColourListLoop
    PROCESSING_DONE

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
