osfind = &FFCE
osbget = &FFD7
osargs = &FFDA
osrdch = &FFE0
osasci = &FFE3
osnewl = &FFE7
oswrch = &FFEE

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
    JSR readParameter
    CMP #0
    BNE exit
    JSR openFile
    BNE exit
    JSR readContents
.exit
    \ TODO RTS vs BRK
    RTS

INCLUDE "../utf8.asm"
INCLUDE "../charDefinitions.asm"

.end

SAVE "u8type", start, end
