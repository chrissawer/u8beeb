buildRom = TRUE

osfind = &FFCE
osbget = &FFD7
osargs = &FFDA
osrdch = &FFE0
osasci = &FFE3
osnewl = &FFE7
oswrch = &FFEE

comline = &F2

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
\TODO
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

ORG &8000
.start
    EQUB 0, 0, 0 \ language entry point
    JMP service  \ service entry point
    EQUB &82     \ ROM type
    EQUB offset MOD 256
    EQUB 1       \ version
.title
    EQUS "UTF-8 Tools"
    EQUB 0
    EQUS "0.1"
.offset
    EQUB 0
    EQUS "(C) 2022 Chris Sawer"
    EQUB 0

.service
    PHA
    CMP #9 : BEQ help
    CMP #4 : BEQ u8beeb
    PLA
    RTS

.help
    TYA : PHA
    TXA : PHA
    JSR doHelp
    PLA : TAX
    PLA : TAY
    PLA
    RTS

.doHelp
    JSR osnewl
    LDX #0
    LDA title,X
.helpLoop
    JSR osasci
    INX
    LDA title,X
    BNE helpLoop
    JSR osnewl
    RTS

.u8beeb
    TYA : PHA
    TXA : PHA
    LDX #&FF
    DEY
.u8beebCommandLoop
    INX
    INY
    LDA (comline),Y
    \AND #&DF \ TODO uppercase
    CMP command,X
    BEQ u8beebCommandLoop
    LDA command,X
    BPL done
    CMP #&FF
    BNE done
    INX \ TODO this assumes a single space
    JSR init \ X contains offset of space
    PLA
    PLA
    PLA
    LDA #&00
    RTS
.done
    PLA : TAX
    PLA : TAY
    PLA
    RTS

.command
    EQUS "U8TYPE"
    EQUB &FF

.init
    LDA #0
    STA flags
    STA bytesToSkip
    STA nextReuseSlot

    JSR readParameter
    CMP #0 : BNE exit

    JSR openFile
    CMP #0 : BNE exit

    JSR readContents
.exit
    RTS

INCLUDE "../utf8.asm"
INCLUDE "../charDefinitions.asm"
.end

SAVE "u8rom", start, end
