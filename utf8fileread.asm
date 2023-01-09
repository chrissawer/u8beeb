.readParameter \ return 0 in A for success, non-0 for failure
IF buildRom
ELSE
    LDA #1
    LDY #0
    LDX #controlBlock
    JSR osargs \ AUG p337, returns parameters space separated, &0D terminated
    LDA (controlBlock),Y
    CMP #&D
    BNE readParameterOk
    LDA #1 \ error 1 and return not ok
    PHA
        JSR printError
    PLA
    RTS
.readParameterOk
ENDIF
    LDA #0 \ return ok
    RTS

.openFile
IF buildRom
    \ set up X and Y to point to command line argument
    TXA
    CLC
    ADC comline
    TAX
    LDA #0
    ADC comline+1
    TAY
ELSE
    \ read X and Y from controlBlock as populated by osargs
    LDX controlBlock
    LDY controlBlock+1
ENDIF
    LDA #&40
    JSR osfind \ ADUG p178 "OSFIND Open a File", needs filename pointer in controlBlock
    BNE openFileOk
    LDA #2 \ error 2 and return not ok
    PHA
        JSR printError
    PLA
    RTS
.openFileOk
    STA fileHandle
    LDA #0 \ return ok
    RTS

.readContents
    \ TODO macroify this
    \ ADUG p188 "OSFSC Check EOF" [A/Y destroyed, X ret val]
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ zeroByteFile

    \ ADUG p156 "OSBGET Read Data Byte" [X preserved, Y fileHandle, A ret val]
    LDY fileHandle : JSR osbget : STA byteReadB
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ oneByteFile

    LDY fileHandle : JSR osbget : STA byteReadC
    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BEQ twoByteFile

.readContentsLoop
    LDY fileHandle : JSR osbget
    LDX byteReadB : STX byteReadA \ Shuffle B -> A
    LDX byteReadC : STX byteReadB \         C -> B
    STA byteReadC \ Store new byte in C

    LDA bytesToSkip : BNE skipCheck
    LDY byteReadC : LDX byteReadB : LDA byteReadA
    JSR checkBytes : STA bytesToSkip
.skipCheck
    DEC bytesToSkip

    LDX fileHandle : LDA #1 : JSR osfsc
    CPX #&FF : BNE readContentsLoop

    LDA bytesToSkip : BEQ twoByteFile \ strangely twoByteFile code for now works fine!
\ oneByteFile - TODO zeroByteFile
    LDA byteReadC : LDX #&FF : LDY #&FF
    JSR checkBytes
    \JSR printMessagesFromFlags Chris TODO restore
    JMP closeFile

.zeroByteFile
    LDA #3 \ error 3
    JSR printError
    JMP closeFile

.oneByteFile
    LDA byteReadB : LDX #&FF : LDY #&FF
    JSR checkBytes
    \JSR printMessagesFromFlags Chris TODO restore
    JMP closeFile

.twoByteFile
    LDA byteReadB : LDX byteReadC : LDY #&FF
    JSR checkBytes
    CMP #2 : BEQ bothBytesRead
    LDA byteReadC : LDX #&FF : LDY #&FF
    JSR checkBytes
.bothBytesRead
    \JSR printMessagesFromFlags Chris TODO restore
    \ fall through to closeFile
.closeFile
    LDA #0 \ Close
    LDY fileHandle
    JSR osfind
    RTS

.osfsc
    JMP (&21E)
