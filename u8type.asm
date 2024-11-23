INCLUDE "../commonDefinitions.asm"

buildRom = FALSE

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

    JSR readParameter
    CMP #0 : BNE exit

    JSR openFile
    CMP #0 : BNE exit

    JSR readContents
.exit
    RTS

INCLUDE "../utf8fileread.asm"
INCLUDE "../utf8core.asm"
INCLUDE "../charDefinitions.asm"

.end

SAVE "u8type", start, end
