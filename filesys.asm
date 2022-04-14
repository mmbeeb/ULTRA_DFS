	\\ Acorn DFS
	\\ filesys.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

.Go_FSCV
	JMP (FSCV)

.errDISK
	JSR ReportError_start_checkbuffer	;Disk Error
IF sys>120 OR ultra			;Change of spelling
	EQUS &00, "Disc "
ELSE
	EQUS &00, "Disk "
ENDIF
	BCC ReportError_continue

.errBAD
	JSR ReportError_start_checkbuffer	;Bad Error
	EQUS &00, "Bad "
	BCC ReportError_continue

	\\ Report error and check if writing channel buffer.
.ReportError_start_checkbuffer
{
	LDA WRITING_BUFFER
	BNE notbuf			;If not writing channel buffer.

	JSR ClearEXECSPOOLFileHandle

.notbuf
	LDA #&FF
	STA LoadedCatDrive
	STA WRITING_BUFFER		;Not writing buffer
}

	\\ Report error/start new report.
.ReportError_start
IF ultra
	JSR LEDS_reset			;Reset keyboard LEDs
ENDIF

	LDX #&02
	LDA #&00			;"BRK"
	STA &0100

	\ If string terminated by bit 7 being set, return to caller,
	\ e.g. part of a larger error string, else report error.
	\ On entry/exit : X = offset of &100 + 1
.ReportError_continue
{
IF NOT(ultra)
	STA &B3				;Save A???
ENDIF

	PLA 				;Word &AE = Calling address + 1
	STA &AE
	PLA 
	STA &AF

IF NOT(ultra)
	LDA &B3				;Restore A???
ENDIF

	LDY #&00			;First byte of string always error nr.
	JSR inc_word_AE
	LDA (&AE),Y
	STA &0101
	DEX

.errstr_loop
	JSR inc_word_AE
	INX 
	LDA (&AE),Y
	STA &0100,X
	BMI prtstr_return2		;If bit 7 set, return to caller.
	BNE errstr_loop

	JSR TUBE_RELEASE
	JMP &0100
}

	\ **** Print String ****
	\ String terminated if bit 7 set.
	\ Exit: AXY preserved, C=0.
.PrtString
{
	STA &B3				;Print String (bit 7 terminates)

	PLA 				;A,X,Y preserved
	STA &AE
	PLA 
	STA &AF

	LDA &B3

	PHA 				;Save A & Y
	TYA 
	PHA 
	LDY #&00

.prtstr_loop
	JSR inc_word_AE
	LDA (&AE),Y
	BMI prtstr_return1		;If end

	JSR PrtChrA
	JMP prtstr_loop

.prtstr_return1
	PLA 				;Restore A & Y
	TAY 
	PLA 
}

.prtstr_return2
	CLC 
	JMP (&00AE)			;Return to caller

.PrtHexLoNibfullstop
	JSR prthexLoNib

.PrtFullSstop
	LDA #&2E

.PrtChrA
	JSR rememberAXY			;Print character
	PHA 
	LDA #&EC
	JSR osbyteX00YFF
	TXA 				;X = chr destination
	PHA 
	ORA #&10
	JSR osbyte03A			;Disable spooled output
	PLA 
	TAX 
	PLA 
	JSR OSASCI			;Output chr
	JMP osbyte03X			;Restore previous setting

IF sys>120 OR ultra
	\ Print BCD/Hex : A=number
.PrtBcdA
	JSR BinaryToBCD
ENDIF

.PrtHexA
	PHA 
	JSR Alsr4
	JSR prthexLoNib
	PLA

.prthexLoNib
	JSR prthexnibcalc
	BNE PrtChrA			;always

.prthexnibcalc
{
	AND #&0F
	CMP #&0A
	BCC prthex

	ADC #&06

.prthex
	ADC #&30
	RTS
}

.copyvars
{
	JSR copyword
	DEX 
	DEX 				;restore X to entry value
	JSR copybyte1			;copy word (b0)+y to 1072+x

.copybyte1
	LDA (&B0),Y
	STA VAL_1072,X
	INX
	INY
	RTS
}

.copyword
{
	JSR copybyte2			;Note: to BC,X in 0.90

.copybyte2
	LDA (&B0),Y
	STA &BA,X
	INX 
	INY 
	RTS
}

	\ Read filename to &1000
	\ 1st pad &1000-&103F with spaces

.read_afspTextPointer
	JSR Set_CurDirDrv_ToDefaults
	JMP rdafsp_entry

.read_afspBA_reset
	JSR Set_CurDirDrv_ToDefaults

.read_afspBA
	LDA &BA				;**Also creates copy at &C5
	STA TextPointer
	LDA &BB
	STA TextPointer+1
	LDY #&00
	JSR GSINIT_A

.rdafsp_entry
	LDX #&20			;Get drive & dir (X="space")
	JSR GSREAD_A			;get C
	BCS errBadName			;IF end of string

	STA VAL_1000
	CMP #&2E			;C="."?
	BNE rdafsp_notdot		;ignore leading …'s

.rdafsp_setdrv
	STX DirectoryParam		;Save directory (X)
	BEQ rdafsp_entry		;always

.rdafsp_notdot
	CMP #&3A			;C=":"? (Drive number follows)
	BNE rdafsp_notcolon

	JSR Param_DriveNo_BadDrive			;Get drive no.
IF sys=120
	JSR SetCurrentDriveA
ENDIF
	JSR GSREAD_A
	BCS errBadName			;IF end of string

	CMP #&2E			;C="."?
	BEQ rdafsp_entry		;err if not eg ":0."

.errBadName
	JSR errBAD
	EQUS &CC, "name", 0

.rdafsp_notcolon
{
	TAX 				;X=last Chr
	JSR GSREAD_A			;get C
	BCS rdafsp_padall		;IF end of string

	CMP #&2E			;C="."?
	BEQ rdafsp_setdrv

	LDX #&01			;Read rest of filename

.rdafsp_rdfnloop
	STA VAL_1000,X
	INX 
	JSR GSREAD_A
	BCS rdafsp_padX			;IF end of string

	CPX #&07
	BNE rdafsp_rdfnloop
	BEQ errBadName
}

.GSREAD_A
{
	JSR GSREAD			;GSREAD ctrl chars cause error
	PHP 				;C set if end of string reached
	AND #&7F
	CMP #&0D			;Return?
	BEQ dogsrd_exit

	CMP #&20			;Control character? (I.e. <&20)
	BCC errBadName

	CMP #&7F			;Backspace?
	BEQ errBadName

.dogsrd_exit
	PLP 
	RTS
}

.rdafsp_padall
	LDX #&01			;Pad all with spaces

.rdafsp_padX
{
	LDA #&20			;Pad with spaces

.rdafsp_padloop
	STA VAL_1000,X
	INX 
	CPX #&40			;Why &40? : Wildcards buffer!
	BNE rdafsp_padloop

	LDX #&06			;Copy from &1000 to &C5

.rdafsp_cpyfnloop
	LDA VAL_1000,X			;7 byte filename
	STA &C5,X
	DEX 
	BPL rdafsp_cpyfnloop

	RTS
}

.Prt_filenameY
{
	JSR rememberAXY
	LDA swsp+&0E0F,Y
	PHP 
	AND #&7F			;directory
	BNE prt_filename_prtchr

	JSR Prt2spaces			;if no dir. print "  "
	BEQ prt_filename_nodir		;always?

.prt_filename_prtchr
	JSR PrtChrA			;print dir
	JSR PrtFullSstop		;print "."

.prt_filename_nodir
	LDX #&06			;print filename

.prt_filename_loop
	LDA swsp+&0E08,Y
	AND #&7F
	JSR PrtChrA
	INY 
	DEX 
	BPL prt_filename_loop

	JSR Prt2spaces			;print "  "
	LDA #&20			;" "
	PLP 
	BPL prt_filename_notlocked

	LDA #&4C			;"L"

.prt_filename_notlocked
	JSR PrtChrA			;print "L" or " "
	LDY #&01
}

.prt_Yspaces
	JSR Prtspace
	DEY 
	BNE prt_Yspaces

	RTS

.Alsr6and3
	LSR A
	LSR A

.Alsr4and3
	LSR A
	LSR A

.Alsr2and3
	LSR A
	LSR A
	AND #&03
	RTS

IF sys>120
.LoadAddr_TestBit17
{
	AND #&08			;\ Only called from AB54
	BEQ la_nothost			;\ Tests high bit of load

	LDA #&03			;\ address (bit 17)

.la_nothost
	RTS
}
ENDIF

.Alsr5	LSR A

.Alsr4	LSR A

.Alsr3	LSR A
	LSR A
	LSR A
	RTS

.Aasl5	ASL A

.Aasl4	ASL A
	ASL A
	ASL A
	ASL A
	RTS

	\ Set up read/write variables (InitNMIVars)

.Setup_RW_Variables
{
IF sys=120
	\8271
	LDA &BC				; Memory Address
	STA NMI_DataPointer
	LDA &BD
	STA NMI_DataPointer+1
	LDA #&FF			; Calc.counter/trk/sec
	STA Track
	LDX &C1				; Len b8-b15
	INX
	STX NMI_Counter2
	LDA &C2				; "mixed byte"
	JSR Alsr4and3
	STA NMI_Counter3		; Len b16-17
	INC NMI_Counter3
	LDA &C0				; Len b0-b7
	STA NMI_Counter1		; ' bytes last sector 0=&100
	BNE calsctrksec

	DEC NMI_Counter2		; ' Sectors
	BNE calsctrksec

	DEC NMI_Counter3		; ' 1=Host

.calsctrksec
	LDA &C2				; Strt Sec b8-b9
	AND #&03
	TAX				; X=b8-b9
	LDA &C3				; Strt Sec b0-b7

.calctrksec_loop2
	SEC

.calctrksec_loop
	INC Track			; Calc first trk/sec
	SBC #&0A			; first loop trk=FF+1=0
	BCS calctrksec_loop		; sec>=10

	DEX
	BPL calctrksec_loop2

	ADC #&0A
	STA Sector
ELSE
	\1770
	LDA #&05
	STA OWCtlBlock+5
	LDA CurrentDrv
	STA OWCtlBlock			;?1090=drive
	LDA #&0A
	STA &B0
	LDA &BC
	STA OWCtlBlock+1		;!1091=load address
	LDA &BD
	STA OWCtlBlock+2
	LDA VAL_1074
	STA OWCtlBlock+3
	LDA VAL_1075
	STA OWCtlBlock+4
	LDA #&FF
	STA OWCtlBlock+7
	LDA &C2				;C0/C1/C2=Length
	JSR Alsr4and3
	STA OWCtlBlock+&A
	LDA &C0
	STA OWCtlBlock+&B
	LDA &C1
	STA OWCtlBlock+9
	LDA &C2				;C2/C3=Sector
	AND #&03
	TAX 				;Calculate Track/Sector
	LDA &C3

.calc_tracksec1
	SEC 

.calc_tracksec2
	INC OWCtlBlock+7		;?1097=Track
	SBC &B0
	BCS calc_tracksec2

	DEX 
	BPL calc_tracksec1

	ADC &B0
	STA OWCtlBlock+8		;?1098=Sector
ENDIF
}

.getcat_exit
	RTS

.getcatentry_afsp_TxtP
	JSR read_afspTextPointer
	BMI getcatentry			;always

.getcatentry_afsp_BA
	JSR read_afspBA_reset

.getcatentry
	JSR get_cat_firstentry
	BCS getcat_exit

.err_FILENOTFOUND
	JSR ReportError_start
	EQUS &D6, "Not found", 0

IF sys>120 OR ultra
.CMD_EX
IF sys=224
	JSR SetTextPointerXY
ENDIF
	JSR Set_CurDirDrv_ToDefaults	;\ *EX (<dir>)
	JSR GSINIT_A
	BEQ cmd_ex_nullstr		;If null string

	JSR ReadDirDrvParameters2	;Get dir

.cmd_ex_nullstr
	LDA #&2A			;"*"
	STA VAL_1000
	JSR rdafsp_padall
	JSR parameter_afsp
	JSR getcatentry
	JMP cmd_info_loop
ENDIF

.CMD_INFO
IF sys=224
	JSR SetTextPointerXY
ENDIF
	JSR parameter_afsp		;*INFO <afsp>
IF sys=224
	JSR GSINIT_A
	BEQ jmp_errBadName
ELSE
	JSR Param_SyntaxErrorIfNull
ENDIF
	JSR getcatentry_afsp_TxtP

.cmd_info_loop
	JSR prt_InfoLineY
	JSR get_cat_nextentry
	BCS cmd_info_loop

	RTS

IF sys=224
.jmp_errBadName
	JMP errBadName
ENDIF

IF sys>120
.get_cat_entry81XX
	JSR SUB_93F9_rdCatalogue_81_check	;\ Get cat entry
	LDA #&00
	BEQ get_cat_firstentry3		;\ always
ENDIF

.get_cat_entry80
{
	LDX #&06			;copy filename from

.getcatloop1
	LDA &C5,X			;&C5 to &1058
	STA VAL_1058,X
	DEX 
	BPL getcatloop1

	LDA #&20
	STA VAL_105F

	LDA #&58
	BNE get_cat_firstentry2		;always
}

.get_cat_nextentry
	LDX #&00			;Entry: wrd &B6 -> first entry
	BEQ getcatloop2			;always

.get_cat_firstentry
	LDA #&00			;now first byte @ &1000+X

.get_cat_firstentry2
	PHA 				;Set up & return first
	JSR CheckCurDrvCatalog		;catalogue entry matching
	PLA 				;string at &1000+A

.get_cat_firstentry3
	TAX
IF sys=120
	LDA #HI(swsp+&0E00)		;*This is moved below for 2.26
	STA &B7
ENDIF
	LDA #LO(swsp+&0E00)		;word &B6 = &E00 = PTR
	STA &B6

.getcatloop2
	LDY #LO(swsp+&0E00)
IF sys>120
	LDA #HI(swsp+&0E00)		;string at &1000+A
	STA &B7
ENDIF
	LDA &B6
	CMP FilesX8
	BCS matfn_exit_C_0		;If >FilesX8 Exit with C=0

	ADC #&08
	STA &B6				;word &B6 += 8
	JSR MatchFilename
	BCC getcatloop2			;not a match, try next file

	LDA DirectoryParam
	LDY #&07
	JSR MatchChrA
	BNE getcatloop2			;If directory doesn't match

	LDY &B6
	SEC 				;Return, Y=offset-8, C=1

.Yless8
	DEY 
	DEY 
	DEY 
	DEY 
	DEY 
	DEY 
	DEY 
	DEY 
	RTS

.MatchFilename
{
	JSR rememberAXY			;Match filename at &1000+X

.matfn_loop1
	LDA VAL_1000,X			;with that at (&B6)
	CMP VAL_10CE
	BNE matfn_nomatch		;e.g. If="*"

	INX

.matfn_loop2
	JSR MatchFilename
	BCS matfn_exit			;If match then exit with C=1

	INY 
	CPY #&07
	BCC matfn_loop2			;If Y<7

.matfn_loop3
	LDA VAL_1000,X			;Check next char is a space!
	CMP #&20
	BNE matfn_exit_C_0		;If exit with c=0 (no match)

	RTS 				;exit with C=1

.matfn_nomatch
	CPY #&07
	BCS matfn_loop3			;If Y>=7
	JSR MatchChrA
	BNE matfn_exit_C_0

	INX 
	INY 
	BNE matfn_loop1			;next chr;
}
.matfn_exit_C_0
	CLC 				;exit with C=0

.matfn_exit
	RTS

.MatchChrA
{
	CMP VAL_10CE
	BEQ matchr_exit			;eg. If "*"

	CMP VAL_10CD
	BEQ matchr_exit			;eg. If "#"

	JSR IsAlphaChar
	EOR (&B6),Y
	BCS matchr_notalpha		;IF not alpah char

	AND #&5F

.matchr_notalpha
	AND #&7F

.matchr_exit
	RTS 				;If n=1 then matched
}

.UcaseA
{
	PHP 
	JSR IsAlphaChar
	BCS ucasea

	AND #&5F			;A=Ucase(A)

.ucasea
	AND #&7F			;Ignore bit 7
	PLP 
	RTS
}

.DeleteCatEntryY
{
	JSR CheckFileNotLockedOrOpen	;Delete catalogue entry

.delcatloop
	LDA swsp+&0E10,Y
	STA swsp+&0E08,Y
	LDA swsp+&0F10,Y
	STA swsp+&0F08,Y
	INY 
	CPY FilesX8
	BCC delcatloop

	TYA 
	SBC #&08
	STA FilesX8
	CLC
}
.print_infoline_exit
	RTS

.IsAlphaChar
{
	PHA 
	AND #&5F			;Uppercase
	CMP #&41
	BCC isalpha1			;If <"A"

	CMP #&5B
	BCC isalpha2			;If <="Z"

.isalpha1
	SEC 

.isalpha2
	PLA 
	RTS
}

.prt_InfoMsgY
	BIT FSMessagesOnIfZero		;Print message
	BMI print_infoline_exit

.prt_InfoLineY
	JSR rememberAXY			;Print info
	JSR Prt_filenameY
	TYA 				;Save offset
	PHA 
	LDA #LO(VAL_1060)		;word &B0=1060
	STA &B0
	LDA #HI(VAL_1060)
	STA &B1
	JSR ReadFileAttribsToB0		;create no. str
	LDY #&02
	JSR Prtspace			;print "  "
	JSR PrintHex3Byte		;Load address
	JSR PrintHex3Byte		;Exec address
	JSR PrintHex3Byte		;Length
	PLA 
	TAY 
	LDA swsp+&0F0E,Y		;First sector high bits
	AND #&03
	JSR prthexLoNib
	LDA swsp+&0F0F,Y		;First sector low byte
	JSR PrtHexA
IF sys=120
	JSR prtNewLine
	JMP FDC_SetToCurrentDrv
ELSE
	JMP prtNewLine
ENDIF

.PrintHex3Byte
{
	LDX #&03			;eg print "123456 "

.printhex3byte_loop
	LDA VAL_1062,Y
	JSR PrtHexA
	DEY 
	DEX 
	BNE printhex3byte_loop

	JSR Yplus7
	JMP Prtspace
}

.LoadCurDrvCat
	JSR rememberAXY
	JMP LoadCurDrvCatalog

.ReadFileAttribsToB0
{
	JSR rememberAXY			;Decode file attribs
	TYA 
	PHA 				;bytes 2-11
	TAX 				;X=cat offset
	LDY #&12			;Y=(B0) offset
	LDA #&00			;Clear pwsp+2 to pwsp+&11

.readfileattribs_clearloop
	DEY 
	STA (&B0),Y
	CPY #&02
	BNE readfileattribs_clearloop

.readfileattribs_copyloop
	JSR readfileattribs_copy2bytes	;copy low bytes of
	INY 				;load/exec/length
	INY 
	CPY #&0E
	BNE readfileattribs_copyloop

	PLA 
	TAX 
	LDA swsp+&0E0F,X
	BPL readfileattribs_notlocked	;If not locked

	LDA #&08
	STA (&B0),Y			;pwsp+&E=8

.readfileattribs_notlocked
	LDA swsp+&0F0E,X		;mixed byte
	LDY #&04			;load address high bytes
	JSR readfileattribs_addrHiBytes
	LDY #&0C			;file length high bytes
	LSR A
	LSR A
	PHA 
	AND #&03
	STA (&B0),Y
	PLA 
	LDY #&08			;exec address high bytes

.readfileattribs_addrHiBytes
	LSR A
	LSR A				;/4
	PHA 
	AND #&03
IF sys=120
	STA (&B0),Y
ENDIF
	CMP #&03
IF sys=120
	BNE readfileattribs_exits
ELSE
	BNE readfileattribs_nothost
ENDIF
	LDA #&FF
	STA (&B0),Y
	INY

.readfileattribs_nothost
	STA (&B0),Y

.readfileattribs_exits
	PLA 
	RTS 

.readfileattribs_copy2bytes
	JSR readfileattribs_copy1byte

.readfileattribs_copy1byte
	LDA swsp+&0F08,X
	STA (&B0),Y
	INX 
	INY 
	RTS
}

.inc_word_AE
{
	INC &AE
	BNE inc_word_AE_exit

	INC &AF

.inc_word_AE_exit
	RTS
}

	\\ Remember A X and Y sub routine
.rememberAXY
	PHA 				;calling subroutine exited
	TXA 
	PHA 
	TYA 
	PHA 
	\\ Push return address (rAXY_restore)
	LDA #HI(rAXY_restore-1)
	PHA
	LDA #LO(rAXY_restore-1)
	PHA

.rAXY_loop_init
{
	LDY #&05			; for y=5 to 1

.rAXY_loop
	TSX 
	LDA &0107,X
	PHA 
	DEY 
	BNE rAXY_loop			; next

	\\ Remove original calling routine's return
	\\ address from stack by moving last 10 bytes
	\\ on stack up two places

	LDY #&0A			; for y=A to 1

.rAXY_loop2
	LDA &0109,X
	STA &010B,X
	DEX 
	DEY 
	BNE rAXY_loop2			; next

	\\ Discard duplicate X & Y
	PLA 
	PLA
}

	\\ Restore A,X,Y and return
.rAXY_restore
	PLA 
	TAY 
	PLA 
	TAX 
	PLA 
	RTS

.rememberXYonly
	PHA 
	TXA 
	PHA 
	TYA 
	PHA 
	JSR rAXY_loop_init

	\\ Change value of A
.axyret1
	TSX 
	STA &0103,X
	JMP rAXY_restore

IF sys>120 OR ultra
	\ Convert binary in A to BCD
.BinaryToBCD
{
	JSR rememberXYonly
	TAY 
	BEQ bbcd_exit			;If nothing to do!

	CLC 
	SED 
	LDA #&00

.bbcd_loop
	ADC #&01
	DEY 
	BNE bbcd_loop

	CLD 

.bbcd_exit
	RTS
}

.ShowChrA
{
	AND #&7F			;If A<&20 OR >=&7F return "."
	CMP #&7F			;Ignores bit 7
	BEQ showchrdot

	CMP #&20
	BCS showchrexit

.showchrdot
	LDA #&2E			;"."

.showchrexit
	RTS
}

	\ Convert chr to binary?
.ChrToBinaryA
	SEC
	SBC #&30
	BCC hexbin_invalid

	CMP #&0A			;C=A>=&A
	RTS

	\ Hex in A to binary
.HexToBinaryA
{
	JSR UcaseA
	JSR ChrToBinaryA
	BCC hexbin_exit			;If valid

	SBC #&07
	BCC hexbin_invalid

	CMP #&0A
	BCC hexbin_invalid

	CMP #&10

.hexbin_exit
	RTS
}

.hexbin_invalid
	SEC 
	RTS

	\ Convert decimal to binary
.Decimal_TxtPtrToBinary
{
	JSR GSINIT_A
	SEC 
	BEQ decbin_4			;If null str

	PHP 
	LDA #&00
	STA &B9
	BEQ decbin_2			;always

.decbin_1
	JSR ChrToBinaryA
	BCS decbin_3			;If invalid

	STA &B8
	LDA &B9
	ASL A
	STA &B9
	ASL A
	ASL A
	ADC &B9
	ADC &B8
	STA &B9				;?B9=?B9 X 10 + ?B8

.decbin_2
	JSR GSREAD
	BCC decbin_1			;If not end of str

	LDA &B9
	PLP 
	CLC 
	RTS
 
.decbin_3
	PLP 

.decbin_4
	RTS
}
ENDIF


.fscv5_CAT
	JSR SetTextPointerXY
IF sys=120
	JSR CheckCurDrvCatalog2
ELSE
	JSR Param_OptionalDriveNo
	JSR LoadCurDrvCatalog
ENDIF

.prt_catalogue2
{
	LDY #&FF			;** PRINT CAT
	STY &A8				;Y=FF
	INY 
	STY &AA				;Y=0

.cat_titleloop
	LDA swsp+&0E00,Y		;print disk title
	CPY #&08
	BCC cat_titlelo

	LDA swsp+&0EF8,Y

.cat_titlelo
	JSR PrtChrA
	INY 
	CPY #&0C
	BNE cat_titleloop

	JSR PrtString			;Print " (n) FM "; n=cycle no.
	EQUS " ("			;Print "Drive "
	LDA swsp+&0F04
	JSR PrtHexA
	JSR PrtString
	EQUS ")"
IF sys>120
	EQUS " FM"
ENDIF
	EQUS 13, "Drive "
	LDA CurrentDrv
	JSR prthexLoNib			;print drv.no.
	LDY #&0D
	JSR prt_Yspaces			;print 13 spaces
	JSR PrtString
	EQUS "Option "
	LDA swsp+&0F06
	JSR Alsr4
	PHA 
	JSR prthexLoNib			;print option.no
	JSR PrtString			;print " ("
	EQUS " ("
	LDY #&03			;print option.name
	PLA 
	ASL A
	ASL A
	TAX

.cat_printoptionnameloop
	LDA diskoptions_table,X
	JSR PrtChrA
	INX 
	DEY 
	BPL cat_printoptionnameloop

	JSR PrtString			;print ") Dir. :"
	EQUS ")", 13, "Dir. :"
	LDA DEFAULT_DRIVE
	JSR PrtHexLoNibfullstop		;print driveno+"."
	LDA DEFAULT_DIR
	JSR PrtChrA			;print dir
	LDY #&0B
	JSR prt_Yspaces			;print 11 spaces
	JSR PrtString
	EQUS "Lib. :"			;print "Lib. :"
	LDA LIB_DRIVE
	JSR PrtHexLoNibfullstop		;print library.drv+"."
	LDA LIB_DIR
	JSR PrtChrA			;print library.dir
	JSR prtNewLine			;print
	LDY #&00			;Mark files in cur dir

.cat_curdirloop
	CPY FilesX8			;no.of.files?
	BCS cat_sortloop1		;If @ end of catalogue

	LDA swsp+&0E0F,Y
	EOR DEFAULT_DIR
	AND #&5F
	BNE cat_curdirnext		;If not current dir

	LDA swsp+&0E0F,Y		;Set dir to null, sort=>first
	AND #&80			;Keep locked flag (bit 7)
	STA swsp+&0E0F,Y

.cat_curdirnext
	JSR Yplus8
	BCC cat_curdirloop		;always

.cat_sortloop1
	LDY #&00			;Any unmarked files?
	JSR cat_getnextunmarkedfile
	BCC cat_printfilename		;If yes

	LDA #&FF
	STA LoadedCatDrive
	JMP prtNewLine			;** EXIT OF PRINT CAT

.cat_getnextunmarkedfile_loop
	JSR Yplus8

.cat_getnextunmarkedfile
	CPY FilesX8
	BCS cat_exit			;If @ end of cat exit, c=1

	LDA swsp+&0E08,Y
	BMI cat_getnextunmarkedfile_loop	;If marked file

.cat_exit
	RTS 

.cat_printfilename
	STY &AB				;save Y=cat offset
	LDX #&00

.cat_copyfnloop
	LDA swsp+&0E08,Y		;Copy filename to 1060
	JSR UcaseA
	STA VAL_1060,X
	INY 
	INX 
	CPX #&08
	BNE cat_copyfnloop		;Chk fn < all other unmarked files

.cat_comparefnloop1
	JSR cat_getnextunmarkedfile	;Next unmarked file
	BCS cat_printfn			;If last file, so print anyway

	SEC 
	LDX #&06

.cat_comparefnloop2
	LDA swsp+&0E0E,Y		;compare filenames
	JSR UcaseA			;(catfn-memfn)
	SBC VAL_1060,X
	DEY 
	DEX 
	BPL cat_comparefnloop2

	JSR Yplus7
	LDA swsp+&0E0F,Y		;compare dir
	JSR UcaseA			;(clrs bit 7)
	SBC VAL_1067
	BCC cat_printfilename		;If catfn<memfn

	JSR Yplus8
	BCS cat_comparefnloop1		;else memfn>catfn

.cat_printfn
	LDY &AB				;Y=cat offset
	LDA swsp+&0E08,Y		;mark file as printed
	ORA #&80
	STA swsp+&0E08,Y
	LDA VAL_1067			;dir
	CMP &AA				;dir being printed
	BEQ cat_samedir			;If in same dir

	LDX &AA
	STA &AA				;Set dir being printed
	BNE cat_samedir			;If =0 =default dir

	JSR prtNewLine			;Two newlines after def dir

.cat_newline
	JSR prtNewLine
	LDY #&FF
	BNE cat_skipspaces		;always => ?&A8=0

.cat_samedir
	LDY &A8				;[if ?&A0<>0 = first column]
	BNE cat_newline

	LDY #&05			;print column gap
	JSR prt_Yspaces			;print 5 spaces => ?&A8=1

.cat_skipspaces
	INY 
	STY &A8
	LDY &AB				;Y=cat offset
	JSR Prt2spaces			;print 2 spaces
	JSR Prt_filenameY		;Print filename
	JMP cat_sortloop1
}

.diskoptions_table
	EQUS "off", 0, "LOAD", "RUN", 0, "EXEC"

.GetnextblockY
	LDA swsp+&0F0E,Y
	JSR Alsr4and3
	STA &C2				;len byte 3
	CLC 
	LDA #&FF			;-1
	ADC swsp+&0F0C,Y		;+ len byte 1
	LDA swsp+&0F0F,Y		;+ start sec byte 1
	ADC swsp+&0F0D,Y		;+ len byte 2
	STA &C3
	LDA swsp+&0F0E,Y		;start sec byte 2
	AND #&03
	ADC &C2				;calc. next "free" sector
	STA &C2				;wC2=start sec + len - 1

.GetfirstblockY
	SEC 
	LDA swsp+&0F07,Y		;secs on disk
	SBC &C3				;or start sec of prev.
	PHA 				;file
	LDA swsp+&0F06,Y		;- end of prev. file (wC2)
	AND #&03
	SBC &C2
	TAX 
	LDA #&00
	CMP &C0
	PLA 				;ax=secs on disk-next blk
	SBC &C1
	TXA 				;req'd=c0/c1/c4
	SBC &C4				;big enough?

.SERVICE_NULL
.gbpbv0_donothing
	RTS

.cmdlist

	\\ Table 1 Commands
	\\ (Can only be used when DFS is active.)
.cmdtable1
	EQUS "ACCESS", HI(CMD_ACCESS-1), LO(CMD_ACCESS-1),  &30+_afsp_
	EQUS "BACKUP", HI(CMD_BACKUP-1), LO(CMD_BACKUP-1), &04
IF sys=226 OR (sys=120 AND ultra)			;Master version in OS!
	EQUS "CLOSE", HI(CMD_CLOSE-1), LO(CMD_CLOSE-1), &00
ENDIF
	EQUS "COMPACT", HI(CMD_COMPACT-1), LO(CMD_COMPACT-1), &07
	EQUS "COPY", HI(CMD_COPY-1), LO(CMD_COPY-1), _afsp_*16+4
IF sys<>224
	EQUS "DELETE", HI(CMD_DELETE-1), LO(CMD_DELETE-1), _fsp_
ENDIF
	EQUS "DESTROY", HI(CMD_DESTROY-1), LO(CMD_DESTROY-1), _afsp_
	EQUS "DIR", HI(CMD_DIR-1), LO(CMD_DIR-1), &06
	EQUS "DRIVE", HI(CMD_DRIVE-1), LO(CMD_DRIVE-1), &09
	EQUS "ENABLE", HI(CMD_ENABLE-1), LO(CMD_ENABLE-1), &00
IF sys=226 OR (sys=120 AND ultra)
	EQUS "EX", HI(CMD_EX-1), LO(CMD_EX-1), &06
ENDIF
IF sys>120 OR ultra
	EQUS "FORM", HI(CMD_FORM-1), LO(CMD_FORM-1), &BA
	EQUS "FREE", HI(CMD_FREE-1), LO(CMD_FREE-1), &07
ENDIF
IF sys<>224
	EQUS "INFO", HI(CMD_INFO-1), LO(CMD_INFO-1), _afsp_
ENDIF
	EQUS "LIB", HI(CMD_LIB-1), LO(CMD_LIB-1), &06
IF sys>120 OR ultra
	EQUS "MAP", HI(CMD_MAP-1), LO(CMD_MAP-1), &07
ENDIF
	EQUS "RENAME", HI(CMD_RENAME-1), LO(CMD_RENAME-1), &05
	EQUS "TITLE", HI(CMD_TITLE-1), LO(CMD_TITLE-1), &08
IF sys>120 OR ultra
	EQUS "VERIFY", HI(CMD_VERIFY-1), LO(CMD_VERIFY-1), &0B
ENDIF
	EQUS "WIPE", HI(CMD_WIPE-1), LO(CMD_WIPE-1), _afsp_
IF ultra
	EQUB HI(UnrecCommand_Table4-1), LO(UnrecCommand_Table4-1)
ELSE
	EQUB HI(cmdnotintable1-1), LO(cmdnotintable1-1)
ENDIF

IF sys=120 AND NOT(ultra)
	cmdtable1_count = 14
ELIF sys=224
	cmdtable1_count = 16
ELSE;sys=226
	cmdtable1_count = 20
ENDIF

	\\ Table 2 Utils commands
	\\ (Can still be used if DFS is inactive.)
.cmdtable2
IF sys<>224
	EQUS "BUILD", HI(CMD_BUILD-1), LO(CMD_BUILD-1), _fsp_
	EQUS "DISC", HI(CMD_DISK-1), LO(CMD_DISK-1), &00
	EQUS "DUMP", HI(CMD_DUMP-1), LO(CMD_DUMP-1), _fsp_
	EQUS "LIST", HI(CMD_LIST-1), LO(CMD_LIST-1), _fsp_
IF sys=226 OR ultra
	EQUS "ROMS", HI(CMD_ROMS-1), LO(CMD_ROMS-1), &0C
ENDIF
	EQUS "TYPE", HI(CMD_TYPE-1), LO(CMD_TYPE-1), _fsp_
ENDIF
IF sys=224 OR ultra
	EQUS "DISC", HI(CMD_DISK-1), LO(CMD_DISK-1), &00
ENDIF
	EQUS "DISK", HI(CMD_DISK-1), LO(CMD_DISK-1), &00
	EQUB HI(gbpbv0_donothing-1), LO(gbpbv0_donothing-1)

IF sys=120 AND NOT(ultra)
	cmdtable2_count = 5
ELIF sys=224
	cmdtable2_count = 1
ELSE;sys=226
	cmdtable2_count = 6
ENDIF

	\\ Table 3 Help
.cmdtable3
	EQUS "DFS", HI(CMD_DFS-1), LO(CMD_DFS-1), &00
IF ultra
	EQUS "DUTILS", HI(CMD_DUTILS-1), LO(CMD_DUTILS-1), &00
ENDIF
IF sys<>224				;Master utilities in OS!
	EQUS "UTILS", HI(CMD_UTILS-1), LO(CMD_UTILS-1), &00
ENDIF
	EQUB HI(CMD_NOTHELPTBL-1), LO(CMD_NOTHELPTBL-1)

IF ultra
IF sys=224
	cmdtable3_count = 2
ELSE
	cmdtable3_count = 3
ENDIF
ELIF sys=224
	cmdtable3_count = 1
ELSE
	cmdtable3_count = 2
ENDIF

	\ offset of table
	cmdtab1=LO(cmdtable1-cmdtable1-3)
	cmdtab2=LO(cmdtable2-cmdtable1-3)
	cmdtab3=LO(cmdtable3-cmdtable1-3)

IF ultra
	\\ Table 4 DUTILS
.cmdtable4
	EQUS "DBOOT", HI(dboot-1), LO(dboot-1), &0D
	EQUS "DCAT", HI(dcat-1), LO(dcat-1), &0F
	EQUS "DDISKS", HI(ddisks-1), LO(ddisks-1), &06
	EQUS "DFORM", HI(dform-1), LO(dform-1), &0E
	EQUS "DFREE", HI(dfree-1), LO(dfree-1), &00
	EQUS "DIN", HI(CMD_DIN-1), LO(CMD_DIN-1), &D6
	EQUS "DKILL", HI(dkill-1), LO(dkill-1), &0E
	EQUS "DLOCK", HI(dlock-1), LO(dlock-1), &0D
	EQUS "DNEW", HI(dnew-1), LO(dnew-1), &06
	EQUS "DONBOOT", HI(donboot-1), LO(donboot-1), &DC
	EQUS "DOUT", HI(CMD_DOUT-1), LO(CMD_DOUT-1), &06
	EQUS "DRECAT", HI(drecat-1), LO(drecat-1), &00
	EQUS "DRESTORE", HI(drestore-1), LO(drestore-1), &0E
	EQUS "DROM", HI(drom-1), LO(drom-1), &1B
	EQUS "DUNLOCK", HI(dunlock-1), LO(dunlock-1), &0D

	EQUS "DABOUT", HI(CMD_DABOUT-1), LO(CMD_DABOUT-1), &00
	EQUB HI(cmdnotintable1-1), LO(cmdnotintable1-1)

	cmdtable4_count = 14

	cmdtab4=LO(-3)

.din
.dboot
.dcat
.ddisks
.dlock
.dunlock
.dfree
.dkill
.drestore
.dnew
.dform
.donboot
.drecat
.drom
;.dabout
	JMP errSYNTAX

	\ Try Table 4 (DUTILS) commands.
.UnrecCommand_Table4
	LDX #cmdtab4
	SEC
	BCS UnrecCommandTextPointerX_TabC
ENDIF

.fscv3_unreccommand
	JSR SetTextPointerXY
	LDX #cmdtab1

 	\ X = table offset
.UnrecCommandTextPointerX
IF ultra
	\ Ultra verion allows for another table (DUTILS).
	\ This is to overcome the 256 byte limit.
	\ If C=0 table = table1 ... else table4 ...

	CLC

.UnrecCommandTextPointerX_TabC
ENDIF
{
IF ultra
	ROR cmdtab_flag			;Bit 7 = C
ENDIF

	TYA		 		;save Y
	PHA

.unrecloop1
	INX 				;Next 3 bytes (3 x INX) ignored
	INX 				;contain addr/code of prev.

	PLA		 		;restore Y
	PHA 
	TAY
	JSR GSINIT_A			;TextPointer+Y = cmd line

IF ultra
	JSR cmdtab_getchr
ELSE
	INX 				;(Assume X preserved)
	LDA cmdtable1,X
ENDIF
	BMI gocmdcode			;If end of table.

	DEX		 		;init next loop 
	DEY

	STX LastCommand			;Used if syntax error

.unrecloop2
IF ultra
	INY
	JSR cmdtab_getchr
ELSE
	INX 				;X=start of next string-1 
	INY
	LDA cmdtable1,X
ENDIF
	BMI endofcmd_oncmdline		;end of table entry - matched!

	EOR (TextPointer),Y
	AND #&5F			;ignore case
	BEQ unrecloop2	 		;while chrs eq go loop2

	DEX		 		;init next loop

.unrecloop3
IF ultra
	JSR cmdtab_getchr
ELSE
	INX				;find end of table entry
	LDA cmdtable1,X
ENDIF
	BPL unrecloop3

	LDA (TextPointer),Y		;does cmd line end with full stop.
	CMP #&2E
	BNE unrecloop1 			;If no, doesn't match

	INY
	BCS gocmdcode

.endofcmd_oncmdline
	LDA (TextPointer),Y		;If >="." (always)
	JSR IsAlphaChar			;matched table entry
	BCC unrecloop1			;if more alpha chrs

.gocmdcode
	PLA 				;Forget Y

IF ultra
	BIT cmdtab_flag
	BMI gotab4
ENDIF

	LDA cmdtable1,X	 		;Push sub address and
	PHA				;return to it!
	LDA cmdtable1+1,X
	PHA 
	RTS

IF ultra
.gotab4
	LDA cmdtable4,X	
	PHA
	LDA cmdtable4+1,X
	PHA 
	RTS
ENDIF
}

IF ultra
	\ Get next char from command table.
.cmdtab_getchr
	INX

.cmdtab_getchr2
{
	BIT cmdtab_flag
	BMI tab4

	LDA cmdtable1,X
	RTS

.tab4	LDA cmdtable4,X
	RTS
}
ENDIF

.SetTextPointerXY
	STX TextPointer
	STY TextPointer+1
	LDY #&00
	RTS 

.GSINIT_A
	CLC 
	JMP GSINIT

.CMD_WIPE
{
	JSR parameter_afsp
	JSR Param_SyntaxErrorIfNull
	JSR getcatentry_afsp_TxtP

.wipeloop
	LDA swsp+&0E0F,Y
	BMI wipelocked			;Ignore locked files

	JSR Prt_filenameY

IF sys=120
	JSR PrtString
	EQUS " : "
	NOP
ENDIF
	JSR ConfirmYN			;Confirm Y/N
	BNE wipeno

IF sys>120
	LDX &B6
ENDIF
	JSR CheckForDiskChange
IF sys>120
	STX &B6
ENDIF
	JSR DeleteCatEntry_AdjustPtr
IF sys>120
	STY &AB
ENDIF
	JSR SaveCatToDisk
IF sys>120
	LDA &AB
	STA &B6
ENDIF

.wipeno
	JSR prtNewLine

.wipelocked
	JSR get_cat_nextentry
	BCS wipeloop

	RTS
}

.CMD_DELETE
	JSR parameter_fsp
	JSR Param_SyntaxErrorIfNull
	JSR getcatentry_afsp_TxtP
	JSR prt_InfoMsgY
	JSR DeleteCatEntryY
	JMP SaveCatToDisk

.CMD_DESTROY
{
	JSR IsEnabledOrGo		;If NO it returns to calling sub
	JSR parameter_afsp
	JSR Param_SyntaxErrorIfNull
	JSR getcatentry_afsp_TxtP

.destroyloop1
	LDA swsp+&0E0F,Y		;Print list of matching files
	BMI destroylocked1		;IF file locked

	JSR Prt_filenameY
	JSR prtNewLine

.destroylocked1
	JSR get_cat_nextentry
	BCS destroyloop1

	JSR GoYN			;Confirm Y/N
	BEQ destroyyes

	JMP prtNewLine

.destroyyes
	JSR CheckForDiskChange
	JSR get_cat_firstentry

.destroyloop2
	LDA swsp+&0E0F,Y
	BMI destroylocked2		;IF file locked

	JSR DeleteCatEntry_AdjustPtr

.destroylocked2
	JSR get_cat_nextentry
	BCS destroyloop2

	JSR SaveCatToDisk

.msgDELETED
	JSR PrtString
	EQUS &0D, "Deleted", &0D
}

.Yplus8
	INY
 
.Yplus7
	INY 
	INY 
	INY 
	INY 
	INY 
	INY 
	INY 
	RTS

.DeleteCatEntry_AdjustPtr
	JSR DeleteCatEntryY		;Delete cat entry
	LDY &B6
	JSR Yless8			;Take account of deletion
	STY &B6				;so ptr is at next file
	RTS

	\ *DRIVE <drive> (40)(80)
.CMD_DRIVE
{
	JSR Param_SyntaxErrorIfNull
	JSR Param_DriveNo_BadDrive
	STA DEFAULT_DRIVE

IF sys>120
	JSR Decimal_TxtPtrToBinary	;Get disk size (shouldn't
	BEQ setdrv_exit			;be used with a 40 track drive)

	CMP #&28
	BEQ setdrv_size			;If 40 track, C=1

	CMP #&50
	CLC 
	BEQ setdrv_size			;If 80 track, C=0

	JMP errSYNTAX

.setdrv_size
	PHP 
	LDX DEFAULT_DRIVE
	LDA DRIVE_MODE,X
	ROL A
	PLP 
	ROR A
	STA DRIVE_MODE,X		;Bit 7=Size (1=40,0=80)

.setdrv_exit
	RTS
ENDIF
}

.SetCurrentDriveA
IF sys=120
	JSR FDC_WaitIfBusy
ENDIF
.SetCurrentDriveA_nowait
	AND #&03
	STA CurrentDrv
	RTS

.osfileFF_loadfiletoaddr
	JSR getcatentry_afsp_BA		;Get Load Addr etc.
	JSR PrivateWorkspacePointer	;from catalogue
	JSR ReadFileAttribsToB0		;(Just for info?)

IF sys>120
	LDA #&80
ENDIF
.loadfileY
IF sys>120
	STA OWCtlBlock+6		;Param block FDC command
ENDIF
	STY &BA
	LDX #&00
	LDA &BE				;If ?BE=0 don't
	BNE load_LoadAddr		;do Load Addr

	INY 				;else use existing
	INY 
	LDX #&02
	BNE load_copyfileinfo_loop	;always

.load_LoadAddr
	LDA swsp+&0F0E,Y
	STA &C2
	JSR LoadAddrHi2

.load_copyfileinfo_loop
	LDA swsp+&0F08,Y		;"mixed byte"
	STA &BC,X			;BC-C3 / BE-C3
	INY 				;=file attributes
	INX 
	CPX #&08
	BNE load_copyfileinfo_loop

	JSR ExecAddrHi2
	LDY &BA
	JSR prt_InfoMsgY		;pt. print file info
IF sys>120
	JMP rwblock2
ENDIF

.LoadMemBlock
IF sys=120
	JSR LoadNMI1Read_TubeInit
ELSE
	LDA #&80
ENDIF
	BNE rwblock1			;always

.osfile0_savememblock
	JSR CreateFile_fspBA
	JSR PrivateWorkspacePointer
	JSR ReadFileAttribsToB0

.SaveMemBlock
IF sys=120
	JSR LoadNMI0Write_TubeInit
ELSE
	LDA #&A0
ENDIF

.rwblock1
IF sys>120
	STA OWCtlBlock+6

.rwblock2
ENDIF
	JSR Setup_RW_Variables
IF sys=120
	JSR FDC_SetupRW
	LDA #&01
	JSR NMI_RELEASE_WaitFDCbusy
	PHA
	LDA NotTUBEOpIf0
	BEQ LABEL_A708_exit		; If not tube txf

.ReleaseTUBE
	LDA #&81			; Release tube
	JSR TubeCode
	PLA
	RTS

.NMI_TUBE_RELEASE
	JSR NMI_RELEASE

	\ A preserved
.TUBE_RELEASE
	PHA
	LDA #&EA			; Tube present?
	JSR osbyteX00YFF
	TXA
	BNE ReleaseTUBE			; Branch if TUBE present

.LABEL_A708_exit
	PLA
	RTS	
ELSE
	JSR SUB_9445
	LDA #&01
	RTS
ENDIF

.fscv2_4_RUN
	JSR SetTextPointerXY		;** RUN

.cmdnotintable1
	JSR SetWordBAtxtptr		;(Y preserved)
	STY VAL_10DA			;Y=0
	JSR read_afspBA_reset		;Look in default drive/dir
	STY VAL_10D9			;Y=text ptr offset
IF sys=120
	JSR get_cat_firstentry
ELSE
	JSR get_cat_entry81XX
ENDIF
	BCS runfile_found		;If file found

	LDY VAL_10DA
	LDA LIB_DIR			;Look in library
	STA DirectoryParam
	LDA LIB_DRIVE
	JSR SetCurrentDriveA
	JSR read_afspBA
IF sys=120
	JSR get_cat_firstentry
else
	JSR get_cat_entry81XX
ENDIF
	BCS runfile_found		;If file found

IF sys=224
	LDA TextPointer
	ADC VAL_10DA
	TAX
	LDY TextPointer+1
	BCC skip_8867

	INY

.skip_8867
	LDA #&0B
	JMP Go_FSCV
ELSE
.errBADCOMMAND
	JSR errBAD
	EQUS &FE, "command", 0
ENDIF

.runfile_found
IF sys>120
	LDA swsp+&0F0E,Y		;\ New to DFS
	JSR Alsr6and3			;\ If ExecAddr=&FFFFFFFF *EXEC it
	CMP #&03
	BNE runfile_run			;If ExecAddr<>&FFFFFFFF

	LDA swsp+&0F0A,Y
	AND swsp+&0F0B,Y
	CMP #&FF
	BNE runfile_run			;If ExecAddr<>&FFFFFFFF

	LDX #&06			;Else *EXEC file  (New to DFS)

.runfile_exec_loop
	LDA VAL_1000,X			;Move filename
	STA VAL_1007,X
	DEX 
	BPL runfile_exec_loop

	LDA #&0D
	STA VAL_100E
	LDA #&45
	STA VAL_1000			;"E"
	LDA #&2E			;"."
	STA VAL_1001
	LDA #&3A			;":"
	STA VAL_1002
	LDA CurrentDrv
	ORA #&30
	STA VAL_1003			;Drive number X
	LDA #&2E			;"."
	STA VAL_1004
	STA VAL_1006
	LDA DirectoryParam		;Directory D
	STA VAL_1005
	LDX #LO(VAL_1000)		;"E.:X.D.FILENAM"
	LDY #HI(VAL_1000)
	JMP OSCLI
ENDIF

.runfile_run
IF sys>120
	LDA #&81			;Load file (host|sp)
ENDIF
	JSR loadfileY
	CLC 
	LDA VAL_10D9			;Word &10D9 += text ptr
	TAY 				;i.e. -> parameters
	ADC TextPointer
	STA VAL_10D9
	LDA TextPointer+1
	ADC #&00
	STA VAL_10DA
	LDA VAL_1076			;Execution address hi bytes
	AND VAL_1077
	ORA TubePresentIf0
	CMP #&FF
	BEQ runfile_inhost		;If in Host

	LDA &BE				;Copy exec add low bytes
	STA VAL_1074
	LDA &BF
	STA VAL_1075
	JSR TUBE_CLAIM
	LDX #LO(VAL_1074)		;Tell second processor
	LDY #HI(VAL_1074)		;to execute program
	LDA #&04			;(Exec addr @ 1074)
	JMP TubeCode

.runfile_inhost
	LDA #&01			;Execute program
	JMP (&00BE)

.SetWordBAtxtptr
	LDA #&FF
	STA &BE
	LDA TextPointer
	STA &BA
	LDA TextPointer+1
	STA &BB
	RTS

.CMD_DIR
	LDX #&00			;** Set DEFAULT DIR/DRV
	BEQ setdirlib

.CMD_LIB
	LDX #&02			;** Set LIBRARY DIR/DRV

.setdirlib
	JSR ReadDirDrvParameters
	STA DEFAULT_DRIVE,X
	LDA DirectoryParam
	STA DEFAULT_DIR,X
	RTS

	\\ Copy valuable data from static workspace (sws) to 
	\\ private workspace (pws).
	\\ For 1.20 (and Ultra) sws data 10C0-10FF, and 1100-11BF.
	\\ For 2.24 and 2.26: sws data 10C0-10ED*, and 1100-11BF.
	\\ (*SRAM uses pws+EE to +FF for its private workspace.)
.SaveStaticToPrivateWorkspace
{
	JSR rememberAXY
	LDA &B0
	PHA
	LDA &B1
	PHA

	JSR SetPrivateWorkspacePointer

	LDY #&00

.stat_loop1
	CPY #&C0
	BCC stat_YlessC0

	LDA VAL_1000,Y
	BCS stat_YgteqC0

.stat_YlessC0
	LDA swsp+&1100,Y

.stat_YgteqC0
	STA (&B0),Y

IF sys=120 and NOT(ultra)
	DEY
ELSE
	INY 				;\ diff. here
	CPY #&EE			;\ only copy 10C0 to 10ED
ENDIF
	BNE stat_loop1

	PLA 				;Restore previous values
	STA &B1
	PLA 
	STA &B0
	RTS
}

.ReadDirDrvParameters
	LDA DEFAULT_DIR			;Read drive/directory from
	STA DirectoryParam		;command line
	JSR GSINIT_A
	BNE ReadDirDrvParameters2	;If not null string

	LDA #&00
	JSR SetCurrentDriveA		;Drive 0!
	BEQ rdd_exit1			;always

.ReadDirDrvParameters2
{
	LDA DEFAULT_DRIVE
	JSR SetCurrentDriveA

.rdd_loop
	JSR GSREAD_A
	BCS errBADDIRECTORY		;If end of string

	CMP #&3A			;":"?
	BNE rdd_exit2

	JSR Param_DriveNo_BadDrive			;Get drive
	JSR GSREAD_A
	BCS rdd_exit1			;If end of string

	CMP #&2E			;"."?
	BEQ rdd_loop

.errBADDIRECTORY
	JSR errBAD
	EQUS &CE, "dir", 0

.rdd_exit2
	STA DirectoryParam
	JSR GSREAD_A			;Check end of string
	BCC errBADDIRECTORY		;If not end of string
}
.rdd_exit1
	LDA CurrentDrv
	RTS

.CMD_TITLE
{
	JSR Param_SyntaxErrorIfNull	;** RETITLE DISK
	JSR Set_CurDirDrv_ToDefaults
	JSR LoadCurDrvCat		;load cat
	LDX #&0B			;blank title
IF sys=120
	LDA #&20
ELSE
	LDA #&00
ENDIF

.cmdtit_loop1
	JSR SetDiskTitleChr
	DEX 
	BPL cmdtit_loop1

.cmdtit_loop2
	INX 				;read title for parameter
	JSR GSREAD_A
	BCS jmp_savecattodisk

	JSR SetDiskTitleChr
	CPX #&0B
	BCC cmdtit_loop2
}

.jmp_savecattodisk
	JMP SaveCatToDisk		;save cat

.SetDiskTitleChr
{
	CPX #&08
	BCC setdisttit_page

	STA swsp+&0EF8,X
	RTS 

.setdisttit_page
	STA swsp+&0E00,X
	RTS
}

.CMD_ACCESS
{
	JSR parameter_afsp		;** ACCESS
	JSR Param_SyntaxErrorIfNull
	JSR read_afspTextPointer
	LDX #&00			;X=locked mask
	JSR GSINIT_A
	BNE cmdac_getparam		;If not null string

.cmdac_flag
	STX &AA
	JSR get_cat_firstentry
	BCS cmdac_filefound

	JMP err_FILENOTFOUND

.cmdac_filefound
	JSR CheckFileNotOpen		;Error if it is!
	LDA swsp+&0E0F,Y		;Set/Reset locked flag
	AND #&7F
	ORA &AA
	STA swsp+&0E0F,Y
	JSR prt_InfoMsgY
	JSR get_cat_nextentry
	BCS cmdac_filefound
	BCC jmp_savecattodisk		;Save catalogue

.cmdac_paramloop
	LDX #&80			;Locked bit

.cmdac_getparam
	JSR GSREAD_A
	BCS cmdac_flag			;If end of string

	AND #&5F
	CMP #&4C			;"L"?
	BEQ cmdac_paramloop

.errBADATTRIBUTE
	JSR errBAD
	EQUS &CF, "attribute", 0
}

.fscv0_OPT
{
	JSR rememberAXY
	TXA 
	CMP #&04
	BEQ SetBootOptionY

	CMP #&02
	BCC opts01			;If A<2

.errBADOPTION
	JSR errBAD
	EQUS &CB, "option", 0

.opts01
	LDX #&FF			;*OPT 0,Y or *OPT 1,Y
	TYA 
	BEQ opts01Y

	LDX #&00

.opts01Y
	STX FSMessagesOnIfZero		;=NOT(Y=0), I.e. FF=messages off
	RTS
}

.SetBootOptionY
	TYA 				;*OPT 4,Y
	PHA 
	JSR Set_CurDirDrv_ToDefaults
	JSR LoadCurDrvCatalog		;load cat
	PLA 
	JSR Aasl4
	EOR swsp+&0F06
	AND #&30
	EOR swsp+&0F06
	STA swsp+&0F06
	JMP SaveCatToDisk		;save cat

.errDISKFULL
	JSR errDISK
	EQUS &C6, "full", 0

.CreateFile_fspBA
{
	JSR read_afspBA_reset		;loads cat
	JSR get_cat_firstentry		;does file exist?
	BCC createfile_nodel		;If NO

	JSR DeleteCatEntryY		;delete previous file

.createfile_nodel
	LDA &C0				;save wC0
	PHA 
	LDA &C1
	PHA 
	SEC 
	LDA &C2				;A=1078/C1/C0=start address
	SBC &C0				;B=107A/C3/C2=end address
	STA &C0				;C=C4/C1/C0=file length
	LDA &C3
	SBC &C1
	STA &C1
	LDA VAL_107A
	SBC VAL_1078
	STA &C4				;C=B-A
	JSR CreateFile_2
	LDA VAL_1079			;Load Address=Start Address
	STA VAL_1075			;(4 bytes)
	LDA VAL_1078
	STA VAL_1074
	PLA 
	STA &BD
	PLA 
	STA &BC
	RTS
}

.CreateFile_2
{
	LDA #&00			;NB Cat stored in
	STA &C2				;desc start sec order
	LDA #&02			;(file at 002 last)
	STA &C3				;wC2=&200=sector
	LDY FilesX8			;find free block
	CPY #&F8			;big enough
	BCS errCATALOGUEFULL		;for new file

	JSR GetfirstblockY
	JMP cfile_cont2

.cfile_loop
	BEQ errDISKFULL

	JSR Yless8
	JSR GetnextblockY

.cfile_cont2
	TYA 
	BCC cfile_loop			;If not big enough

	STY &B0				;Else block found
	LDY FilesX8			;Insert space into catalogue

.cfile_insertfileloop
	CPY &B0
	BEQ cfile_atcatentry		;If at new entry

	LDA swsp+&0E07,Y
	STA swsp+&0E0F,Y
	LDA swsp+&0F07,Y
	STA swsp+&0F0F,Y
	DEY 
	BCS cfile_insertfileloop

.cfile_atcatentry
	LDX #&00
	JSR CreateMixedByte

.cfile_copyfnloop
	LDA &C5,X			;Copy filename from &C5
	STA swsp+&0E08,Y
	INY 
	INX 
	CPX #&08
	BNE cfile_copyfnloop

.cfile_copyattribsloop
	LDA &BB,X			;Copy attributes
	DEY 
	STA swsp+&0F08,Y
	DEX 
	BNE cfile_copyattribsloop

	JSR prt_InfoMsgY
	TYA 
	PHA 
	LDY FilesX8
	JSR Yplus8
	STY FilesX8			;FilesX+=8
	JSR SaveCatToDisk		;save cat
	PLA 
	TAY 
	RTS

.errCATALOGUEFULL
	JSR ReportError_start_checkbuffer
	EQUS &BE,"Cat full", 0
}

.CreateMixedByte
	LDA VAL_1076			;Exec address b17,b16
	AND #&03
	ASL A
	ASL A
	EOR &C4				;Length
	AND #&FC
	EOR &C4
	ASL A
	ASL A
	EOR VAL_1074			;Load address
	AND #&FC
	EOR VAL_1074
	ASL A
	ASL A
	EOR &C2				;Sector
	AND #&FC
	EOR &C2
	STA &C2				;C2=mixed byte
	RTS

.CMD_ENABLE
	LDA #&01
	STA CMDEnabledIf1
	RTS

.LoadAddrHi2
{
	LDA #&00
	STA VAL_1075
	LDA &C2
IF sys=120
	JSR Alsr2and3			; load addr
ELSE
	;\ Mix.byte:If b.3 set A=3 else 0
	JSR LoadAddr_TestBit17		;\ Only call to this sub
ENDIF
	CMP #&03
	BNE ldadd_nothost

	LDA #&FF
	STA VAL_1075

.ldadd_nothost
	STA VAL_1074
	RTS
}

.ExecAddrHi2
{
	LDA #&00
	STA VAL_1077
	LDA &C2
	JSR Alsr6and3
	CMP #&03
	BNE exadd_nothost

	LDA #&FF
	STA VAL_1077

.exadd_nothost
	STA VAL_1076
	RTS
}

.Set_CurDirDrv_ToDefaults
	LDA DEFAULT_DIR			;set working dir
	STA DirectoryParam

.Set_CurDrv_ToDefault
	LDA DEFAULT_DRIVE		;set working drive
	JMP SetCurrentDriveA

	\ (<drive>)
.Param_OptionalDriveNo
;.Param_OptionalDriveNo
	JSR GSINIT_A
	BEQ Set_CurDrv_ToDefault	;null string

;.GetDriveNo
	\ <drive>
	\ Exit: A=DrvNo, C=0, XY preserved
.Param_DriveNo_BadDrive
	JSR GSREAD_A			;rd chr C
	BCS errBADDRIVE			;end of str

	CMP #&3A			;C=":"
	BEQ Param_DriveNo_BadDrive			;ignore get next chr

	SEC 
	SBC #&30			;N=C-"0"
	BCC errBADDRIVE			;C<"0"

	CMP #&04
	BCS errBADDRIVE			;C>="4"

	JSR SetCurrentDriveA		;on entry A=drive no (0-3)
	CLC 
	RTS

.errBADDRIVE
	JSR errBAD			;Bad Drive (err#CD)
	EQUS &CD, "drive", 0

.CMD_RENAME
{
IF sys=120
	v = &B3
ELSE
	v = &C4
ENDIF

	JSR parameter_fsp		;** RENAME FILE
	JSR Param_SyntaxErrorIfNull
	JSR read_afspTextPointer
	TYA 
	PHA 
	JSR getcatentry
	JSR CheckFileNotLockedOrOpen
	STY v
	PLA 
	TAY 
	JSR Param_SyntaxErrorIfNull
	LDA CurrentDrv
	PHA 
	JSR read_afspTextPointer
	PLA 
	CMP CurrentDrv
	BNE errBADDRIVE

	JSR get_cat_firstentry
	BCC rname_ok

	CPY v
	BEQ rname_ok

.errFILEEXISTS
	JSR ReportError_start_checkbuffer
	EQUS &C4, "Exists", 0

.rname_ok
	LDY v				;Copy filename
	JSR Yplus8			;from C5 to catalog
	LDX #&07

.rname_loop
	LDA &C5,X
	STA swsp+&0E07,Y
	DEY 
	DEX 
	BPL rname_loop			;else Save catalogue

IF sys>120
	JMP SaveCatToDisk
ENDIF
}

IF sys>120
	INCLUDE "filesys_1770.asm"	;1770 code
ENDIF

.SaveCatToDisk
IF sys=120
	CLC				;Increment Cycle No
	SED
	LDA swsp+&0F04
	ADC #&01
	CLD
	STA swsp+&0F04

.SaveCatToDisk_DontIncCycleNo		;Ultra only
	JSR ResetFDCNMI_SetToCurrentDrv
	JSR SetRW_Attempts

.savecat_attemptsloop
	LDY #&2B
	DEC NMI_RW_attempts
	BMI FDC_ERROR

	JSR FDC_cmdfromtableY1		;verify track 0/secs 8 & 9
	BNE savecat_attemptsloop

	JSR LoadNMI0Write		;defaults to &E00
	BNE rwCatalogue			;always

ELSE
	LDA swsp+&0F04			;Increment Cycle No
	CLC 
	SED
	ADC #&01
	STA swsp+&0F04
	CLD

.SaveCatToDisk_DontIncCycleNo
	LDY #&A0			;Only called after FORMAT
	BNE rwCatalogue			;always

.SUB_93F5_rdCatalogue_81
	LDY #&81
	BNE rwCatalogue			;always

.SUB_93F9_rdCatalogue_81_check
	LDY #&81
	BNE Label_93FF			;always
ENDIF

IF sys=120
.CheckCurDrvCatalog2
	JSR Param_OptionalDriveNo
ENDIF

.CheckCurDrvCatalog
IF sys=120
	JSR FDC_DriveReady
	BEQ LoadCurDrvCatalog

	LDA LoadedCatDrive
	CMP CurrentDrv
	BEQ fdc_cmdfromtbl_exitloop

ELSE
	LDY #&80

.Label_93FF
	BIT FDC_STATUS_COMMAND
	BPL rwCatalogue			;If motor off

	LDA LoadedCatDrive
	CMP CurrentDrv
	BNE rwCatalogue			;If cat not already loaded

	RTS
ENDIF

.LoadCurDrvCatalog
IF sys=120
	JSR ResetFDCNMI_SetToCurrentDrv
	JSR LoadNMI1Read		; defaults to &E00

.rwCatalogue
	LDA #&00
	STA VAL_1073
	STA NotTUBEOpIf0		; Not TUBE!
	JSR FDC_SetupRW
	LDA CurrentDrv
	STA LoadedCatDrive
	JMP NMI_RELEASE_WaitFDCbusy
ELSE
	LDY #&80

.rwCatalogue
	JSR OW7F_InitCtlBlock		;at &1090
	STY OWCtlBlock+6		;command
	LDA CurrentDrv
	STA OWCtlBlock			;drive number
	LDA #&02			;parameter: no of sectors
	STA OWCtlBlock+9
	LDA #HI(swsp+&0E00)		;data address (e.g. &FFFF0E00)
	STA OWCtlBlock+2
	DEC OWCtlBlock+3
	DEC OWCtlBlock+4
	JSR SUB_9445			;1770 code

	LDA CurrentDrv
	STA LoadedCatDrive
	RTS
ENDIF

IF sys=120
	INCLUDE "filesys_8271_part1.asm"
ENDIF

IF sys>120 OR ultra
.CheckESCAPE
	BIT &FF				;Check if ESCAPE presed
	BPL rts9444
ENDIF
.reportESCAPE
	JSR osbyte7E_ack_ESCAPE2
	JSR ReportError_start
	EQUS &11, "Escape", 0
IF sys>120 OR ultra
.rts9444
	RTS
ENDIF

IF sys=120
	INCLUDE "filesys_8271_part2.asm"
ENDIF

IF sys>120
.SUB_9445
{
	JSR ErrorIf_40TrackMode_Write	;"Read Only" if in 40 Track Mode

	LDA #&06
	STA OWCtlBlock+&E		;Try 5 times!

	JSR CheckESCAPE

.Label_9450_tryloop
	LDA OWCtlBlock+7		;A=track
	LDX OWCtlBlock			;X=drive
	LDY DRIVE_MODE,X		;Bit 7 = In 40 Track Mode
	BPL LABEL_945C_normalmode	;If in normal mode

	ASL A				;Double step!

.LABEL_945C_normalmode
	LDY #&18			;Y=disk fault nr.
	CMP #&50
	BCS LABEL_94C1			;If track>=80

	LDX #LO(OWCtlBlock)
	LDY #HI(OWCtlBlock)
	JSR EXECUTE_1770_YX_addr	;YX->ctl block @ 1090
	TAY 				;Y=A=result
	BEQ rts9444			;If no error: exit
	BMI reportESCAPE		;If ESCAPE

	CMP #&12
	BEQ errDISKREADONLY		;If READ ONLY

	CMP #&20			;"Deleted data found"
	BNE Label_948D			;If NOT DELETED DATA

	LDA OWCtlBlock+6		;A=cmd
	ROR A
	BCS rts9444			;If bit 0 set : exit

	JSR ReportError_start			;"EXECUTE ONLY!"
	EQUS &BC, "Execute only", 0

.Label_948D
	CMP #&18			;18=CRC error in ID field
	BNE Label_94BC			;If NOT CRC ERROR

	LDA VAL_108A			;Set to 4 only at 9633
	CMP #&04
	BNE Label_94A9			;If true: don't change Bad Track 1

	LDX OWCtlBlock+6		;X=cmd
	CPX #&81
	BNE Label_94A9			;If not Cmd &81

	LDA #&FF
	EOR BAD_TRACKS			;?&108B = ?&108B EOR &FF
	STA BAD_TRACKS			;Surface 0: Bad Track 1
	BCS Label_94BC			;always

.Label_94A9
	LDX Track
	BEQ Label_94BC			;If TRACK 0

	ROL A
	AND #&80			;Toggle 40 track mode flag
	LDX OWCtlBlock			;X = Drive
	EOR DRIVE_MODE,X
	STA DRIVE_MODE,X
	JSR ErrorIf_40TrackMode_Write

.Label_94BC
	DEC OWCtlBlock+&E
	BNE Label_9450_tryloop		;Try again?!

.LABEL_94C1
	TYA 				;Give up : report error
}
ENDIF

.FDC_ReportDiskFault_A_fault
IF sys>120
	CMP #&12			;Report Disk Error/Fault
	BNE dskfault_notro		;A=FDC result

.errDISKREADONLY
	JSR errDISK
	EQUS &C9, "read only", 0

.dskfault_notro
	PHA 
	JSR errDISK			;"Disk fault FF at :DD TT/SS"
	BRK 
	NOP 
	JSR ReportError_continue
	EQUS &C7, "fault "
	NOP 
	PLA 
ENDIF
	JSR prthex_100_X
	JSR ReportError_continue
	EQUS 0, " at "
IF sys>120
	EQUS ":"
	LDA CurrentDrv
	JSR prthexnib_100_X		;Print drive (DD)
	JSR ReportError_continue
	EQUS 0, " "
ENDIF
	LDA Track
IF sys>120
	BIT VAL_108A
	BPL dskfault_not40		;If not 40 track mode

	LSR A		;Track/2
.dskfault_not40
ENDIF
	JSR prthex_100_X		;Print Track (TT)
	JSR ReportError_continue
	EQUS 0, "/"

IF sys=120
.PrintSectorNrTo100X
	LDY #&30
	JSR FDC_cmdfromtableY1		;A="Scan Sector Number"?
ELSE
	LDA Sector			;Print Sector
	JSR prthex_100_X
	JSR ReportError_continue
	EQUS &C7, 0			;BREAK!

.ErrorIf_40TrackMode_Write
	LDA OWCtlBlock+6		;Trying to write?
	CMP #&A0			;Error if in "40 Track Mode"
	BCC LABEL_9535_RTS		;If A<&A0 ; i.e. not writing

	LDX OWCtlBlock
	LDA DRIVE_MODE,X
	BMI errDISKREADONLY		;If 40 track disk

	RTS
ENDIF

.prthex_100_X
	PHA 
	JSR Alsr4

IF sys=120
	JSR prthexnibcalc
	STA &100,X
	INX
ELSE
	JSR prthexnib_100_X
ENDIF
	PLA

.prthexnib_100_X
	JSR prthexnibcalc
	STA &0100,X
	INX 

.LABEL_9535_RTS
	RTS

IF sys>120
.OW7F_InitCtlBlock
{
	LDX #&0D			;\ Clear &1090-&109D
	LDA #&00			;\ "OS7f style Parameter Block"

.Label_953A
	STA OWCtlBlock-1,X
	DEX 
	BNE Label_953A

	LDA #&05
	STA OWCtlBlock+5		;?&1095=5 = Number of parameters
	RTS
}
ENDIF

\\\\ order of modules change here!!!!
IF sys=120 OR sys=224
	INCLUDE "filesys_random.asm"
ENDIF

.bootLOAD
	EQUS "L.!BOOT", 13

.bootEXEC
	EQUS "E.!BOOT", 13

IF sys=224
	\\ MASTER SERVICE ENTRY
.DFS_SERVICE_ENTRY
{
	BIT PagedROM_PrivWorkspaces,X
	BPL LABEL_9AE6
	BVS LABEL_9AE8

	RTS

.LABEL_9AE6
	BVS exit_9B0E

.LABEL_9AE8
	CMP #&12
	BEQ SERVICE12_init_filesystem

	CMP #&0B
	BCC LABEL_9AFA

	CMP #&26
	BCS exit_9B0E

	CMP #&21
	BCC exit_9B0E

	SBC #&16

.LABEL_9AFA
	ASL A
	TAX
	LDA service_table+1,X
	PHA
	LDA service_table,X
	PHA
	TXA
	LDX PagedRomSelector_RAMCopy
	LSR A
	CMP #&0B
	BCC exit_9B0E

	ADC #&15

.exit_9B0E
	RTS

.service_table
	EQUW SERVICE_NULL-1
	EQUW SERVICE_NULL-1
	EQUW SERVICE02_claim_privworkspace-1
	EQUW SERVICE03_autoboot-1
	EQUW SERVICE04_unrec_command-1
	EQUW SERVICE_NULL-1
	EQUW SERVICE_NULL-1
	EQUW SERVICE_NULL-1
	EQUW SERVICE08_unrec_OSWORD-1
	EQUW SERVICE09_help-1
	EQUW SERVICE0A_claim_statworkspace-1
	EQUW DFS_SERVICE_21-1
	EQUW DFS_SERVICE_22-1
	EQUW SERVICE_NULL-1
	EQUW DFS_SERVICE_24-1
	EQUW DFS_SERVICE_25-1

.SERVICE12_init_filesystem
	JSR rememberAXY
	CPY #&04
	BEQ CMD_DISK

	RTS

.SERVICE03_autoboot
	JSR rememberAXY			;A=3 Autoboot
	STY &B3				;if Y=0 then !BOOT
	LDA #&7A			;Keyboard scan
	JSR OSBYTE			;X=int.key.no
	TXA 
	BMI AUTOBOOT

	CMP #&32			;"D" key
	BEQ normalboot

	CMP #&61			;"Z" key
	BNE exit_9B0E

	JSR TRAP_OSBYTE_SET

.normalboot
	LDA #&78			;write current keys pressed info
	JSR OSBYTE
}
ENDIF

.AUTOBOOT
	LDA &B3				;?&B3=value of Y on call 3

	JSR PrtString
IF ultra
	EQUS "Ultra "
ELSE
	EQUS "Acorn "
ENDIF

IF sys>120
	EQUS "1770 "
ELIF ultra
	EQUS "8271 "
ENDIF
	EQUS "DFS"
	EQUB 13, 13

IF sys=224
	BRA initDFS
ELSE
	BCC initDFS			;always (prtstr preserves A)
ENDIF


.CMD_DISK
	LDA #&FF

	\ Initialise DFS
	\ A = autoboot option
.initDFS
	JSR ReturnWithA_0		;On entry: if A=0 then boot file

.initDFS_26
{
	PHA				;Save autoboot option.
 
	LDA #&06
	JSR Go_FSCV			;new filing system

IF sys>120
	LDA FDC_DATA
ENDIF

	\ Initialise vectors.

	LDX #&0D

.vectloop
	LDA vectors_table,X
	STA &0212,X
	DEX 
	BPL vectloop

	\ Initialise extended vectors.

	LDA #&A8
	JSR osbyteX00YFF

IF sys<>224
	STY &B1
ENDIF
	STX &B0
IF sys=224
	STY &B1
ENDIF

	LDX #&07
	LDY #&1B

.extendedvec_loop
	LDA extendedvectors_table-&1B,Y
	STA (&B0),Y
	INY 
	LDA extendedvectors_table-&1B,Y
	STA (&B0),Y
	INY 
	LDA PagedRomSelector_RAMCopy
	STA (&B0),Y
	INY 
	DEX 
	BNE extendedvec_loop

	\ X = 0
	\ Y = &22 (>3 so not valid drive number)

IF ultra
	STX MMC_STATE			;=0 Card unitialised.
ENDIF

IF sys=120
	STX CurrentDrv			;=0
	STY LoadedCatDrive		;>3
	STY IsDriveReady		;>3
ELSE
	STY LoadedCatDrive		;>3
	STY IsDriveReady		;>3 (not used by 1770)
	STX CurrentDrv			;=0

	LDA #&FF			;\ OSWORD&7F EMULATION
	STA VAL_1087			;\ 1087 = flags

	LDY #&03			;\

.initdfs_loop1
	STA BAD_TRACKS,Y		;\ Bad tracks
	DEY 				;\
	BPL initdfs_loop1		;\
ENDIF

	LDX #&0F			;vectors claimed!
	JSR osbyte8F_servreq

	\ Restore from private workspace?

	JSR SetPrivateWorkspacePointer

	LDY #LO(FORCE_RESET)
	LDA (&B0),Y			;A=PWSP+&D3 (-ve=soft break)
	BPL initdfs_reset		;Branch if power up or hard break.

	PLA 
	PHA 
	BEQ initdfs_reset		;Branch if booting file.

	LDY #LO(PWSP_FULL)
	LDA (&B0),Y			;A=PWSP+&D4
	BMI initdfs_noreset		;Branch if PWSP "empty".

	\ Copy data from private workspace to static workspace,
	\ i.e. to &10C0 - &11BF

	JSR ClaimStaticWorkspace

	LDY #&00

.copyfromPWStoSWS_loop
	LDA (&B0),Y
	CPY #&C0
	BCC copyfromPWS1		;If Y < &C0

	STA VAL_1000,Y
	BCS copyfromPWS2

.copyfromPWS1
	STA swsp+&1100,Y

.copyfromPWS2
	DEY 
	BNE copyfromPWStoSWS_loop

IF ultra
	\ Check VID CRC and if it's wrong reset the filing system.

	JSR VID_calc_crc
	BNE set_defaults		;If wrong then implies DFS workspace corrupt.
ENDIF

	\ Refresh channel block info

	LDA #&A0

.setchansloop
	TAY 
	PHA 
	LDA #&3F
	JSR ChannelFlags_ClearBits	;Clear bits 7 & 6, C=0
	PLA 
	STA swsp+&111D,Y		;Buffer sector hi?
	SBC #&1F			;A=A-&1F-(1-C)=A-&20
	BNE setchansloop
	BEQ initdfs_noreset		;always

	\ Reset DFS

.initdfs_reset
	JSR ClaimStaticWorkspace

	\ Set default dir etc.

.set_defaults
	LDA #&24			;"$"
	STA DEFAULT_DIR
	STA LIB_DIR

	LDY #&00
	STY DEFAULT_DRIVE
	STY LIB_DRIVE

IF NOT(ultra)
	LDY #&00			;Already 0!
ENDIF

	STY VAL_10C0

IF sys=120
	STY NMIstatus
IF ultra
	DEY				;Saves a byte!
ELSE
	LDY #&FF
ENDIF
ELSE
	LDX #&03			;! Reset mode of drives
	TYA 				;! Except Drive 0

.initdfs_loop2
	STA DRIVE_MODE,X		;!
	DEX 				;!
	BNE initdfs_loop2		;!

	DEY 				;Y=&FF
ENDIF

	STY CMDEnabledIf1
	STY FSMessagesOnIfZero
	STY WRITING_BUFFER

IF ultra
	\ Reset the VID?

	\ If booting we always get here, it doesn't
	\ imply the VID is corrupt or that there has been an error.

	\ If booting only reset VID if CRC wrong, else reset VID.
	PLA
	PHA
	BNE vid_reset			;If not booting, force VID reset.

	JSR VID_calc_crc
	BEQ initdfs_noreset		;If VID CRC correct.

.vid_reset	
	JSR VID_do_reset
ENDIF

.initdfs_noreset
IF sys=120
	LDA #&EA			; Tube present?
	JSR osbyteX00YFF		; X=FF if Tube present
	TXA
	EOR #&FF
	STA TubePresentIf0

.Label_B472_fromecocode
	PLA				; LABEL USED @ 9C63 ???
	BNE initdfs_exit		; branch if not boot file
	JSR LoadCurDrvCatalog
ELSE
	JSR TUBE_CheckIfPresent		;Tube present?
	PLA 
	BNE initdfs_exit		;branch if not bootING file

	LDA #&04			;\ 0000 0100   Set bit 2
	ORA DRIVE_MODE			;\ Drive 0 mode
	STA DRIVE_MODE			;\

	JSR SUB_93F5_rdCatalogue_81	;\ Load catalogue?

	LDA #&FB			;\ 1111 1011   Clear bit 2
	AND DRIVE_MODE			;\
	STA DRIVE_MODE			;\
ENDIF

	LDA swsp+&0F06			;Get boot option
	JSR Alsr4
	BNE notOPT0			;branch if not opt.0

.initdfs_exit
	RTS
}

.notOPT0
{
	LDY #HI(bootLOAD)		; boot file?
	LDX #LO(bootLOAD)		; ->L.!BOOT
	CMP #&02
	BCC jmpOSCLI			; branch if opt 1
	BEQ oscliOPT2			; branch if opt 2

	IF HI(bootEXEC)<>HI(bootLOAD)	; Check same page
		LDY #HI(bootEXEC)
	ENDIF
	LDX #LO(bootEXEC)		; ->E.!BOOT
	IF LO(bootEXEC)<>0
		BNE jmpOSCLI		; always branch
	ELSE
		BEQ jmpOSCLI
	ENDIF

.oscliOPT2
	IF HI(bootEXEC+2)<>HI(bootEXEC) ; Check same page
		LDY #HI(bootEXEC+2)
	ENDIF
	LDX #LO(bootEXEC+2)		; ->!BOOT

.jmpOSCLI
	JMP OSCLI
}

IF sys=120 and NOT(ultra)
.CHECK_DFS
	PHA				;Check if FDC present
	LDA FDC_WRCMD_RDSTATUS
	AND #&03
	BNE NO_FDC_
ENDIF

IF sys<>224
IF sys=226 or ultra
	\\ SERVICE ENTRY FOR MODEL B+
.DFS_SERVICE_ENTRY
	JSR SERVICE09_TUBEHelp		;Tube service calls
	PHA
ENDIF

	LDA PagedROM_PrivWorkspaces,X

IF sys=120 and NOT(ultra)
	ASL A
ENDIF

	BMI NO_FDC_			;If FDC not present EXIT

	PLA

	\\ Not on MASTER
.SERVICE01_claim_absworkspace
{
	CMP #&01			;A=1 Claim absolute workspace
	BNE SERVICE02_claim_privworkspace

IF sys>120 OR ultra
IF sys=120
	JSR FDC_8271_CheckPresent	;Ultra 1.20
ELSE
	JSR FDC_1770_CheckPresent
ENDIF
	LDX PagedRomSelector_RAMCopy
	BCS serv1_claim

	LDA #&80			;FDC NOT PRESENT
	STA PagedROM_PrivWorkspaces,X	;Set bit 7
	LDA #&01			;Restore A
	RTS 

.serv1_claim
	LDA #&01			;Restore A
ENDIF
	CPY #&17			;Y=current upper limit
	BCS serv1_exit			;already >=&17

	LDY #&17			;Up upper limit to &17

.serv1_exit
	RTS
}
ENDIF

.SERVICE02_claim_privworkspace
{
IF sys=224
	\ MASTER
	LDA PagedROM_PrivWorkspaces,X
	CMP #&DB
	BCC LABEL_9C66

	TYA
	STA PagedROM_PrivWorkspaces,X

.LABEL_9C66
	PHY
	STA &B1				;Set (B0) as pointer to PWSP
ELSE	
	\ B/B+
	CMP #&02			;A=2 Claim private workspace
	BNE SERVICE03_autoboot

	PHA 
	TYA 				;Y=First available page
	PHA
	STA &B1				;Set (B0) as pointer to PWSP

IF sys=120
	ASL A
	ASL PagedROM_PrivWorkspaces,X	;maintain flag bit (bit 7)
	ROR A
ELSE
	LDY PagedROM_PrivWorkspaces,X
ENDIF
	STA PagedROM_PrivWorkspaces,X
ENDIF

	LDA #&00
	STA &B0

IF sys=226
	CPY &B1				;Private workspace may have moved!
	BEQ srv2_samepage		;If same as before

	LDY #LO(FORCE_RESET)
	STA (&B0),Y			;PWSP?&D3=0

.srv2_samepage
ENDIF

	LDA #&FD			;Read hard/soft BREAK
	JSR osbyteX00YFF		;X=0=soft,1=power up,2=hard
	DEX 
	TXA 				;A=FF=soft,0=power up,1=hard
	LDY #LO(FORCE_RESET)
	AND (&B0),Y
	STA (&B0),Y			;So, PWSP?&D3 is +ve if:
	PHP 				;power up, hard reset or
	INY 				;PSWP page has changed
	PLP 
	BPL srv2_notsoft		;If not soft BREAK

	LDA (&B0),Y			;A=PWSP?&D4
	BPL srv2_notsoft		;If PWSP "full"

	\\ If soft break and pws is empty then I must have owned sws,
	\\ so copy it to my pws.
	JSR SaveStaticToPrivateWorkspace	;Copy valuable data to PWSP

.srv2_notsoft
	LDA #&00
	STA (&B0),Y			;PWSP?&D4=0 = PWSP "full"

IF sys=120
	JSR FDC_Initialise
ENDIF
IF sys=224
	LDA #&02
	LDX PagedRomSelector_RAMCopy
	PLY
	BIT PagedROM_PrivWorkspaces,X
	BMI srv3_exit	
ELSE
	LDX PagedRomSelector_RAMCopy
	PLA 				;restore X & A, Y=Y+2
	TAY
ENDIF
	INY 				;taken 2 pages for pwsp
	INY
}
IF sys<>224
.NO_FDC_
	PLA
ENDIF

.srv3_exit
	RTS

IF sys<>224				;MASTER version is above.
.SERVICE03_autoboot
{
	JSR rememberAXY			;A=3 Autoboot
	CMP #&03
	BNE SERVICE04_unrec_command

	STY &B3				;if Y=0 then !BOOT
IF sys>120
	LDA #&00			;\ Reset Drive 0 mode
	STA &10DE			;\
ENDIF
	LDA #&7A			;Keyboard scan
	JSR OSBYTE			;X=int.key.no
	TXA 
	BMI jmpAUTOBOOT

	CMP #&32			;"D" key
IF sys=120
	BNE srv3_exit
ELSE
	BEQ srv3_normalboot

	CMP #&61			;"Z" key
	BNE srv3_exit

	JSR TRAP_OSBYTE_SET
.srv3_normalboot
ENDIF
	LDA #&78			;write current keys pressed info
	JSR OSBYTE

.jmpAUTOBOOT
	JMP AUTOBOOT
}
ENDIF

.SERVICE04_unrec_command
IF sys=224
	JSR rememberAXY
ELSE
	CMP #&04			;A=4 Unrec Command
	BNE SERVICE12_init_filesystem
ENDIF
	LDX #cmdtab2			;UTILS commands

.jmpunreccmd
	JMP UnrecCommandTextPointerX

IF sys<>224				;MASTER version moved above.
.SERVICE12_init_filesystem
	CMP #&12			;A=&12 Initialise filing system
	BNE SERVICE09_help

	CPY #&04			;Y=ID no. (4=dfs)
	BNE srv_exit

	JMP CMD_DISK
ENDIF

.SERVICE09_help
IF sys=224
	JSR rememberAXY
ELSE
	CMP #&09			;A=9 *HELP
	BNE SERVICE0A_claim_statworkspace
ENDIF

	LDA (TextPointer),Y
	LDX #cmdtab3
	CMP #&0D
	BNE jmpunreccmd

	TYA
	INX
	INX
	LDY #cmdtable3_count

	JMP prthelp			;Print help options

.SERVICE0A_claim_statworkspace
IF sys<>224
	JSR ReturnWithA_0		;Return with A=0
	CMP #&0A			;A=&A Claim Static Workspace
	BNE SERVICE08_unrec_OSWORD	;Another ROM wants the
ENDIF

	JSR SetPrivateWorkspacePointer	;absolute workspace

IF sys<>224
	LDY #&D4
	LDA (&B0),Y
	BPL srv_returnwithA__0A		;If PWSP "full"
ENDIF

	LDY #&00
	JSR ChannelBufferToDiskY	;copy valuable
	JSR SaveStaticToPrivateWorkspace	;data to private wsp
IF sys>120
	JSR SetPrivateWorkspacePointer	;\ Called again?
ENDIF
	LDY #&D4
	LDA #&00			;PWSP?&D4=0 = PWSP "full"
	STA (&B0),Y
	RTS

.srv_returnwithA__0A
	LDA #&0A			;"Not me, try next ROMs"

.srv_returnwithA
	TSX 				;rememberAXY called earlier
	STA &0105,X			;changes value of A in stack

.srv_exit
	RTS

	\ Pointer used by OSWORD routines.
IF sys=120
	OWptr=&B0
ELSE
	OWptr=&C7
ENDIF

.SERVICE08_unrec_OSWORD
IF sys=224
	JSR rememberAXY
	JSR ReturnWithA_0
ELSE
	CMP #&08			;LAST SERVICE CALL
	BNE srv_returnwithA
ENDIF

	LDY &EF				;Osword A reg
	BMI srv_returnwithA

	CPY #&7D
	BCC srv_returnwithA		;exit if osword < &7D or >=&80

	LDX &F0				;Osword X reg
	STX OWptr
	LDX &F1				;Osword Y reg
	STX OWptr+1

	INY
	BPL notOsword7F			; Branch if not OSWORD &7F

IF sys=120
.Osword7F
{
	CLI				; Enable interrupts
	LDY #&00
	LDA (OWptr),Y			; Drive parameter
	BMI osword7F_curdrv		; If -ve use current drive

	JSR SetCurrentDriveA

.osword7F_curdrv
	JSR FDC_SetToCurrentDrv
	INY
	LDX #&02			; bc/bd=oswptr+1/2
	JSR copyvars			; 1074/75=oswptr+3/4
	LDA (OWptr),Y			; oswptr+5 = param.#
	INY
	PHA
	LDA (OWptr),Y			; oswptr+6 = FDC cmd
	PHA
	JSR FDC_WriteCmdA		; FDC CMD
	PLA
	JSR Alsr4
	AND #&01			; 0=init rd/1=init wr
	JSR TubeRoutineA
	ROL A				; 2 or 0
	ADC #&03			; 3or5(tube)/4or6(host)
	JSR NMI_CLAIMA			; 3+4WR, 5+6RD
	LDA &BC				; oswptr+1
	STA NMI_DataPointer
	LDA &BD				; oswptr+2
	STA NMI_DataPointer+1
	LDY #&07
	PLA				; oswptr+5=No.of FDC parameters
	TAX
	BEQ osword7F_result

.osowrd7F_paramloop
	LDA (OWptr),Y
	JSR FDC_WriteParamA
	INY
	DEX
	BNE osowrd7F_paramloop

.osword7F_result
	JSR FDC_Wait
	STA (OWptr),Y
	JMP NMI_TUBE_RELEASE		;A preseved
}
ELSE
	LDX OWptr
	LDY OWptr+1
	JMP Osword7F_8271_Emulation	;8271 emulation
ENDIF

IF sys=120 AND ultra
	\ Used by format and verify.
	\ Real 8271 so we don't need emulation!
	\ Entry: Y:X -> control block
	\ Exit:  A = Result byte
.Osword7F_8271_Emulation
	STX OWptr
	STY OWptr+1
	JMP Osword7F
ENDIF

.notOsword7F
{
	JSR Set_CurDirDrv_ToDefaults
	JSR LoadCurDrvCat
	INY 
	BMI Osword7E			;Branch if OSWORD &7E

	LDY #&00			;OSWORD &7D return cycle no.
	LDA swsp+&0F04
	STA (OWptr),Y
	RTS

.Osword7E
	LDA #&00			;OSWORD &7E
	TAY 
	STA (OWptr),Y
	INY 
	LDA swsp+&0F07			;sector count LB
	STA (OWptr),Y
	INY 
	LDA swsp+&0F06			;sector count HB
	AND #&03
	STA (OWptr),Y
	INY 
	LDA #&00			;result
	STA (OWptr),Y
	RTS
}

IF sys=224
.DFS_SERVICE_21
{
	CPY #&CA
	BCS LABEL_9D1E

	LDY #&CA

.LABEL_9D1E
	RTS
}

.DFS_SERVICE_22
	TYA
	STA PagedROM_PrivWorkspaces,X
	LDA #&22
	INY
	INY
	RTS

.DFS_SERVICE_24
	DEY
	DEY
	RTS

.DFS_SERVICE_25
{
	LDX #&15

.LOOP_9D2D
	LDA DATA_9D3B,X
	STA (TextPointer),Y
	INY
	DEX
	BPL LOOP_9D2D

	LDA #&25
	LDX PagedRomSelector_RAMCopy
	RTS

.DATA_9D3B
	EQUS &04, &15, &11, "    CSID"
	EQUS &04, &15, &11, "    KSID"
}

.DFS_SERVICE_26
	PHY
	LDA #&FF
	JSR initDFS_26 
	PLY
	LDX PagedRomSelector_RAMCopy
	LDA #&26
	RTS	
ENDIF


.FILEV_ENTRY
{
	JSR rememberXYonly
	PHA 
	JSR parameter_fsp

	STX &B0				;XY -> parameter block
	STX VAL_10DB
	STY &B1
	STY VAL_10DC

	LDX #&00			;BA->filename
	LDY #&00			;BC & 1074=load addr (32 bit)
	JSR copyword			;BE & 1076=exec addr

.filev_copyparams_loop
	JSR copyvars			;C0 & 1078=start addr
	CPY #&12			;C2 & 107A=end addr
	BNE filev_copyparams_loop	;(lo word in zp, hi in page 10)

	PLA 
	TAX 
	INX 
IF sys=224
	CPX #&09
ELSE
	CPX #&08			;NB A=FF -> X=0
ENDIF
	BCS filev_unknownop		;IF x>=8 (a>=7)

	LDA findv_tablehi,X		;get addr from table
	PHA 				;and "return" to it
	LDA findv_tablelo,X
	PHA
}
.filev_unknownop
	LDA #&00
	RTS

.FSCV_ENTRY
IF sys=224
	CMP #&0C
ELSE
	CMP #&09
ENDIF
	BCS filev_unknownop

	STX &B5				;Save X

	TAX 
	LDA fscv_tablehi,X
	PHA 
	LDA fscv_tablelo,X
	PHA 
	TXA

	LDX &B5				;Restore X

.gbpbv_unrecop
	RTS

.GBPBV_ENTRY
{
	CMP #&09
	BCS gbpbv_unrecop

	JSR rememberAXY
	JSR ReturnWithA_0
	STX VAL_107D
	STY VAL_107E
	TAY 
	JSR gbpb_gosub
	PHP 
IF sys=120
	JSR TUBE_RELEASE
ELSE
	BIT IsTubeGBPB			;\ slightly different
	BPL gbpb_nottube

	JSR TUBE_RELEASE_NoCheck
.gbpb_nottube
ENDIF
	PLP 
	RTS

.gbpb_gosub
	LDA gbpbv_table1,Y

	STA VAL_10D7
	LDA gbpbv_table2,Y
	STA VAL_10D8
	LDA gbpbv_table3,Y		;3 bit flags: bit 2=tube op

	LSR A
	PHP 				;Save bit 0 (0=write new seq ptr)
	LSR A
	PHP 				;Save bit 1 (1=read/write seq ptr)
	STA VAL_107F			;Save Tube operation
	JSR gbpb_wordB4_word107D	;(B4) -> param blk

	LDY #&0C

.gbpb_ctlblk_loop
	LDA (&B4),Y			;Copy param blk to 1060
	STA VAL_1060,Y
	DEY 
	BPL gbpb_ctlblk_loop

	LDA VAL_1063			;Data ptr bytes 3 & 4
	AND VAL_1064
	ORA TubePresentIf0
	CLC 
	ADC #&01
	BEQ gbpb_nottube1		;If not tube

	JSR TUBE_CLAIM
	CLC 
	LDA #&FF

.gbpb_nottube1
	STA IsTubeGBPB			;GBPB to TUBE IF >=&80
	LDA VAL_107F			;Tube op: 0 or 1
	BCS gbpb_nottube2		;If not tube

	LDX #LO(VAL_1061)
	LDY #HI(VAL_1061)
	JSR TubeCode			;Init TUBE addr @ 1061

.gbpb_nottube2
	PLP 				;Bit 1
	BCS gbpb_rw_seqptr

	PLP 				;Bit 0, here always 0
}
.gbpb_jmpsub
	JMP (VAL_10D7)

.gbpb_rw_seqptr
{
	LDX #&03			;GBPB 1,2,3 or 4

.gbpb_seqptr_loop1
	LDA VAL_1069,X			;!B6=ctl blk seq ptr
	STA &B6,X
	DEX 
	BPL gbpb_seqptr_loop1		;on exit A=file handle=?&1060

	LDX #&B6
	LDY VAL_1060
	LDA #&00
	PLP 				;bit 0
	BCS gpbp_dontwriteseqptr

	JSR argsv_WriteSeqPointerY	;If GBPB 1 & 3

.gpbp_dontwriteseqptr
	JSR argsv_rdseqptr_or_filelen	;read seq ptr to &B6
	LDX #&03

.gbpb_seqptr_loop2
	LDA &B6,X			;ctl blk seq prt = !B6
	STA VAL_1069,X
	DEX 
	BPL gbpb_seqptr_loop2
}

.gbpb_rwdata
{
	JSR gbpb_bytesxferinvert	;Returns with N=1
	BMI gbpb_data_loopin		;always

.gbpb_data_loop
	LDY VAL_1060			;Y=file handle
	JSR gbpb_jmpsub			;*** Get/Put BYTE
	BCS gbpb_data_loopout		;If a problem occurred

	LDX #&09
	JSR gbpb_incdblword1060_X	;inc. seq ptr

.gbpb_data_loopin
	LDX #&05
	JSR gbpb_incdblword1060_X	;inc. bytes to txf
	BNE gbpb_data_loop

	CLC 

.gbpb_data_loopout
	PHP 
	JSR gbpb_bytesxferinvert	;bytes to txf XOR &FFFFFFFF
	LDX #&05
	JSR gbpb_incdblword1060_X	;inc. bytes to txf
	LDY #&0C			;Copy parameter back
	JSR gbpb_wordB4_word107D	;(B4) -> param blk

.gbpb_restorectlblk_loop
	LDA VAL_1060,Y
	STA (&B4),Y
	DEY 
	BPL gbpb_restorectlblk_loop

	PLP 				;C=1=txf not completed
	RTS 				;**** END GBPB 1-4
}

.gbpb8_rdfilescurdir
{
	JSR Set_CurDirDrv_ToDefaults	;GBPB 8
	JSR CheckCurDrvCatalog		;READ FILENAMES IN CURRENT CAT

	LDA #LO(gbpb8_getbyte)		;Address of sub routine 
	STA VAL_10D7
	LDA #HI(gbpb8_getbyte)
	STA VAL_10D8
	BNE gbpb_rwdata			;always

.gbpb8_getbyte
	LDY VAL_1069			;GBPB 8 - Get Byte

.gbpb8_loop
	CPY FilesX8
	BCS gbpb8_endofcat		;If end of catalogue, C=1

	LDA swsp+&0E0F,Y		;Directory
	JSR IsAlphaChar
	EOR DirectoryParam
	BCS gbpb8_notalpha

	AND #&DF

.gbpb8_notalpha
	AND #&7F
	BEQ gbpb8_filefound		;If in current dir

	JSR Yplus8
	BNE gbpb8_loop			;next file

.gbpb8_filefound
	LDA #&07			;Length of filename
	JSR gbpb_gb_SAVEBYTE
	STA &B0				;loop counter

.gbpb8_copyfn_loop
	LDA swsp+&0E08,Y		;Copy fn
	JSR gbpb_gb_SAVEBYTE
	INY 
	DEC &B0
	BNE gbpb8_copyfn_loop

	CLC 				;C=0=more to follow

.gbpb8_endofcat
	STY VAL_1069			;Save offset (seq ptr)
	LDA swsp+&0F04
	STA VAL_1060			;Cycle number (file handle)
	RTS 				;**** END GBPB 8
}

.gbpb5_getmediatitle
{
	JSR Set_CurDirDrv_ToDefaults	;GBPB 5
	JSR CheckCurDrvCatalog		;GET MEDIA TITLE
	LDA #&0C			;Length of title
	JSR gbpb_gb_SAVEBYTE
	LDY #&00

.gbpb5_titleloop
	CPY #&08			;Title
	BCS gbpb5_titlehi

	LDA swsp+&0E00,Y
	BCC gbpb5_titlelo

.gbpb5_titlehi
	LDA swsp+&0EF8,Y

.gbpb5_titlelo
	JSR gbpb_gb_SAVEBYTE
	INY 
	CPY #&0C
	BNE gbpb5_titleloop

	LDA swsp+&0F06			;Boot up option
	JSR Alsr4
	JSR gbpb_gb_SAVEBYTE
	LDA CurrentDrv			;Current drive
	JMP gbpb_gb_SAVEBYTE
}

.gbpb6_rdcurdir_device
	JSR gbpb_SAVE_01		;GBPB 6 - READ CUR DRIVE/DIR
	LDA DEFAULT_DRIVE		;Length of dev.name=1
	ORA #&30			;Drive no. to ascii
	JSR gbpb_gb_SAVEBYTE
	JSR gbpb_SAVE_01		;Lendgh of dir.name=1
	LDA DEFAULT_DIR			;Directory
	BNE gbpb_gb_SAVEBYTE

.gbpb7_rdcurlib_device
	JSR gbpb_SAVE_01		;GBPB 7 - READ LIB DRIVE/DIR
	LDA LIB_DRIVE			;Length of dev.name=1
	ORA #&30			;Drive no. to ascii
	JSR gbpb_gb_SAVEBYTE
	JSR gbpb_SAVE_01		;Lendgh of dir.name=1
	LDA LIB_DIR			;Directory
	BNE gbpb_gb_SAVEBYTE

.gpbp_B8_memptr
	PHA 				;Set word &B8 to
	LDA VAL_1061			;ctl blk mem ptr (host)
	STA &B8
	LDA VAL_1062
	STA &B9
	LDX #&00
	PLA 
	RTS 

.gbpb_incDataPtr
	JSR rememberAXY			;Increment data ptr
	LDX #&01

.gbpb_incdblword1060_X
{
	LDY #&04			;Increment double word

.gbpb_incdblword_loop
	INC VAL_1060,X
	BNE gbpb_incdblworkd_exit

	INX 
	DEY 
	BNE gbpb_incdblword_loop

.gbpb_incdblworkd_exit
	RTS
}

.gbpb_bytesxferinvert
{
	LDX #&03			;Bytes to tranfer XOR &FFFF

.gbpb_bytesxferinvert_loop
	LDA #&FF
	EOR VAL_1065,X
	STA VAL_1065,X
	DEX 
	BPL gbpb_bytesxferinvert_loop

	RTS
}

.gbpb_wordB4_word107D
	LDA VAL_107D
	STA &B4
	LDA VAL_107E
	STA &B5

.gpbp_exit
	RTS

.gbpb_SAVE_01
	LDA #&01
	BNE gbpb_gb_SAVEBYTE		;always

.gbpb_getbyte_SAVEBYTE
	JSR BGETV_ENTRY
	BCS gpbp_exit			;If EOF

.gbpb_gb_SAVEBYTE
{
	BIT IsTubeGBPB
	BPL gBpb_gb_fromhost

	STA TUBE_R3_DATA		;fast Tube Bget
	BMI gbpb_incDataPtr

.gBpb_gb_fromhost
	JSR gpbp_B8_memptr
	STA (&B8,X)
	JMP gbpb_incDataPtr
}

.gbpb_putbytes
	JSR gpbp_pb_LOADBYTE
	JSR BPUTV_ENTRY
	CLC 
	RTS 				;always ok!

.gpbp_pb_LOADBYTE
{
	BIT IsTubeGBPB
	BPL gbpb_pb_fromhost

	LDA TUBE_R3_DATA		;fast Tube Bput
	JMP gbpb_incDataPtr

.gbpb_pb_fromhost
	JSR gpbp_B8_memptr
	LDA (&B8,X)
	JMP gbpb_incDataPtr
}

.fscv_osabouttoproccmd
	BIT CMDEnabledIf1
	BMI parameter_fsp

	DEC CMDEnabledIf1

.parameter_fsp
	LDA #&FF
	STA VAL_10CE

.param_out
	STA VAL_10CD
	RTS 

.parameter_afsp
	LDA #&2A			;"*"
	STA VAL_10CE
	LDA #&23			;"#"
	BNE param_out			;always

.osfile5_rdcatinfo
	JSR CheckFileExists_fspBA	;READ CAT INFO
	JSR ReadFileAttribsToB0
	LDA #&01			;File type: 1=file found
	RTS 

.osfile6_delfile
	JSR CheckFileNotLocked_fsp_BA	;DELETE FILE
	JSR ReadFileAttribsToB0
	JSR DeleteCatEntryY
	BCC osfile_savecat_retA_1

.osfile1_updatecat
	JSR CheckFileExists_fspBA	;UPDATE CAT ENTRY
	JSR osfile_update_loadaddrX
	JSR osfile_update_execaddrX
	BVC osfile_updatelock_savecat

IF sys=120				;Different order
.osfile2_wrloadaddr
	JSR CheckFileExists_fspBA	;WRITE LOAD ADDRESS
	JSR osfile_update_loadaddrX
	BVC osfile_savecat_retA_1
ENDIF

.osfile3_wrexecaddr
	JSR CheckFileExists_fspBA	;WRITE EXEC ADDRESS
	JSR osfile_update_execaddrX
	BVC osfile_savecat_retA_1

IF sys>120
.osfile2_wrloadaddr
	JSR CheckFileExists_fspBA	;WRITE LOAD ADDRESS
	JSR osfile_update_loadaddrX
	BVC osfile_savecat_retA_1
ENDIF

.osfile4_wrattribs
	JSR CheckFileExists_fspBA	;WRITE ATTRIBUTES
	JSR CheckFileNotOpen

.osfile_updatelock_savecat
	JSR osfile_updatelock

.osfile_savecat_retA_1
	JSR jmp_savecattodisk
	LDA #&01
	RTS

.osfile_update_loadaddrX
	JSR rememberAXY			;Update load address
	LDY #&02
	LDA (&B0),Y
	STA swsp+&0F08,X
	INY 
	LDA (&B0),Y
	STA swsp+&0F09,X
	INY 
	LDA (&B0),Y
	ASL A
	ASL A
	EOR swsp+&0F0E,X
	AND #&0C
	BPL osfile_savemixedbyte	;always

.osfile_update_execaddrX
	JSR rememberAXY			;Update exec address
	LDY #&06
	LDA (&B0),Y
	STA swsp+&0F0A,X
	INY 
	LDA (&B0),Y
	STA swsp+&0F0B,X
	INY 
	LDA (&B0),Y
	ROR A
	ROR A
	ROR A
	EOR swsp+&0F0E,X
	AND #&C0

.osfile_savemixedbyte
	EOR swsp+&0F0E,X		;save mixed byte
	STA swsp+&0F0E,X
	CLV 
	RTS

.osfile_updatelock
	JSR rememberAXY			;Update file locked flag
	LDY #&0E
	LDA (&B0),Y
	AND #&0A			;file attributes AUG pg.336
	BEQ osfile_notlocked
	LDA #&80			;Lock!

.osfile_notlocked
	EOR swsp+&0E0F,X
	AND #&80
	EOR swsp+&0E0F,X
	STA swsp+&0E0F,X
	RTS

.CheckFileNotLocked_fsp_BA
	JSR rdafsp_BA			;exit:X=Y=offset
	BCC ExitCallingSubroutine

.CheckFileNotLockedY
	LDA swsp+&0E0F,Y
	BPL chklock_exit

.errFILELOCKED
	JSR ReportError_start_checkbuffer
	EQUS &C3, "Locked", 0

.CheckFileNotLockedOrOpen
	JSR CheckFileNotLockedY

.CheckFileNotOpen
	JSR rememberAXY
	JSR IsFileOpenY
	BCC checkexit

	JMP errFILEOPEN

.CheckFileExists_fspBA
	JSR rdafsp_BA			;exit:X=Y=offset
	BCS checkexit			;If file found

.ExitCallingSubroutine
	PLA 				;Ret. To caller's caller
	PLA 
	LDA #&00

.chklock_exit
	RTS

.rdafsp_BA
	JSR read_afspBA_reset
	JSR get_cat_firstentry
	BCC checkexit

	TYA 
	TAX 				;X=Y=offset

.PrivateWorkspacePointer
	LDA VAL_10DB
	STA &B0
	LDA VAL_10DC
	STA &B1

.checkexit
	RTS 

.CalcRAM
	LDA #&83			;Calc amount of ram available
	JSR OSBYTE			;YX=OSHWM (PAGE)
	STY PAGE
	LDA #&84
	JSR OSBYTE			;YX=HIMEM
	TYA 
	SEC 
	SBC PAGE
	STA RAM_AVAILABLE		;HIMEMpage-OSHWMpage
	RTS

.ClaimStaticWorkspace
IF sys<>224
	LDX #&0A
	JSR osbyte8F_servreq
ENDIF
	JSR SetPrivateWorkspacePointer

	LDY #LO(FORCE_RESET)
	LDA #&FF
	STA (&B0),Y			;Don't force reset.
	STA FORCE_RESET
	INY 
	STA (&B0),Y			;Set PWSP is "empty"
	RTS

.SetPrivateWorkspacePointer
	PHA 				;Set word &B0 to
IF sys=224
	LDA #&00
	STA &B0
ENDIF	
	LDX PagedRomSelector_RAMCopy	;point to Private Workspace
IF sys<>224
	LDA #&00
	STA &B0
ENDIF
	LDA PagedROM_PrivWorkspaces,X
IF sys<>224
	AND #&3F			;bits 7 & 6 are used as flags
ENDIF
	STA &B1
	PLA 
	RTS

IF sys=120
.NMI_CLAIMA
{
	JSR rememberAXY			;Claim & setup NMI
	PHA
	BIT NMIstatus
	BMI claimnmi_alreadyowner	;If owner of NMI

	LDA #&8F			;Iss.pg.rom service request
	LDX #&0C			;service type: NMI CLAIM
	JSR osbyte_Y_FF
	STY NMI_PrevNMIOwner		;=Prev.owner of NMI
	LDA #&FF
	STA NMIstatus

	INC FORCE_RESET			;?FORCE_RESET = 0

.claimnmi_alreadyowner
	PLA				;COPY CODE TO &D00
	TAX
	LDA NMI_Table1,X		;Address of code
	STA &B8
	LDA NMI_Table2,X
	STA &B9
	LDY NMI_Table3,X		;Lenth of code - 1

.claimnmi_copyloop1
	LDA (&B8),Y
	STA NMIRoutine,Y
	DEY
	BPL claimnmi_copyloop1

	CPX #&02
	BCS claimnmi_exit		;exit if X>=2

	LDA PagedRomSelector_RAMCopy
	STA &0D3C			;DFS rom no.
	CPX #&00
	BNE claimnmi_exit		;exit if X<>0

	LDY #&12			;Copy snippet

.claimnmi_copyloop2
	LDA NMI0_snip,Y
	STA &0D0A,Y
	DEY
	BPL claimnmi_copyloop2

.claimnmi_exit
	RTS
}

.NMI_RELEASE_WaitFDCbusy
	JSR FDC_WaitIfBusy		;Release NMI

.NMI_RELEASE
{
	JSR rememberAXY
	BIT NMIstatus
	BPL releasenmi_clr		;If not NMI owner!

	DEC FORCE_RESET			;?FORCE_RESET = &FF

	LDY NMI_PrevNMIOwner
	CPY #&FF
	BEQ releasenmi_clr		;If not prev owner

	LDX #&0B			;Release NMI space
	JSR osbyte8F_servreq		;Type 0B; Y=prev.nmi.owner

.releasenmi_clr
	LDA #&00
	STA NMIstatus
	RTS
}
ENDIF

.osbyte0FA
	JSR rememberAXY

.osbyte0F_flushinbuf
	LDA #&0F
	LDX #&01
	LDY #&00
	BEQ goOSBYTE			;always

.osbyte03A
	TAX

.osbyte03X
	LDA #&03
	BNE goOSBYTE			;always

.osbyte7E_ack_ESCAPE2
	JSR rememberAXY

.osbyte7E_ack_ESCAPE
	LDA #&7E
	BNE goOSBYTE

.osbyte8F_servreq
	LDA #&8F
	BNE goOSBYTE

.osbyteFF_startupopts
	LDA #&FF

.osbyteX00YFF
	LDX #&00

.osbyte_Y_FF
	LDY #&FF

.goOSBYTE
	JMP OSBYTE

	\\ Vector table copied to &0212
.vectors_table
	EQUW &FF1B			; FILEV
	EQUW &FF1E			; ARGSV
	EQUW &FF21			; BGETV
	EQUW &FF24			; BPUTV
	EQUW &FF27			; GBPBV
	EQUW &FF2A			; FINDV
	EQUW &FF2D			; FSCV

	\\ Extended vector table
.extendedvectors_table
	EQUW FILEV_ENTRY
	BRK
	EQUW ARGSV_ENTRY
	BRK
	EQUW BGETV_ENTRY
	BRK
	EQUW BPUTV_ENTRY
	BRK
	EQUW GBPBV_ENTRY
	BRK
	EQUW FINDV_ENTRY
	BRK
	EQUW FSCV_ENTRY
	BRK

	\\ OSFSC table 1 low bytes
.fscv_tablelo
	EQUB LO(fscv0_OPT-1)
	EQUB LO(fscv1_EOF-1)
	EQUB LO(fscv2_4_RUN-1)
	EQUB LO(fscv3_unreccommand-1)
	EQUB LO(fscv2_4_RUN-1)
	EQUB LO(fscv5_CAT-1)
	EQUB LO(fscv6_shutdownfilesys-1)
	EQUB LO(fscv7_hndlrange-1)
	EQUB LO(fscv_osabouttoproccmd-1)
IF sys=224
	EQUB LO(CMD_EX-1)
	EQUB LO(CMD_INFO-1)
	EQUB LO(fscv2_4_RUN-1)
ENDIF

	\\ OSFSC table 2 high bytes
.fscv_tablehi
	EQUB HI(fscv0_OPT-1)
	EQUB HI(fscv1_EOF-1)
	EQUB HI(fscv2_4_RUN-1)
	EQUB HI(fscv3_unreccommand-1)
	EQUB HI(fscv2_4_RUN-1)
	EQUB HI(fscv5_CAT-1)
	EQUB HI(fscv6_shutdownfilesys-1)
	EQUB HI(fscv7_hndlrange-1)
	EQUB HI(fscv_osabouttoproccmd-1)
IF sys=224
	EQUB HI(CMD_EX-1)
	EQUB HI(CMD_INFO-1)
	EQUB HI(fscv2_4_RUN-1)
ENDIF

	\\ OSFIND tables
.findv_tablelo
	EQUB LO(osfileFF_loadfiletoaddr-1)
	EQUB LO(osfile0_savememblock-1)
	EQUB LO(osfile1_updatecat-1)
	EQUB LO(osfile2_wrloadaddr-1)
	EQUB LO(osfile3_wrexecaddr-1)
	EQUB LO(osfile4_wrattribs-1)
	EQUB LO(osfile5_rdcatinfo-1)
	EQUB LO(osfile6_delfile-1)
IF sys=224
	EQUB LO(CreateFile_fspBA-1)
ENDIF

.findv_tablehi
	EQUB HI(osfileFF_loadfiletoaddr-1)
	EQUB HI(osfile0_savememblock-1)
	EQUB HI(osfile1_updatecat-1)
	EQUB HI(osfile2_wrloadaddr-1)
	EQUB HI(osfile3_wrexecaddr-1)
	EQUB HI(osfile4_wrattribs-1)
	EQUB HI(osfile5_rdcatinfo-1)
	EQUB HI(osfile6_delfile-1)
IF sys=224
	EQUB HI(CreateFile_fspBA-1)
ENDIF

IF sys=120
	\\ NMI tables
	\\ Address of routine (low bytes)
.NMI_Table1
	EQUB LO(NMI01_READWRITE)
	EQUB LO(NMI01_READWRITE)
	EQUB LO(NMI2_DONOTHING)
	EQUB LO(NMI3_WRITE_fromTube)
	EQUB LO(NMI4_WRITE_fromMem)
	EQUB LO(NMI5_READ_toTube)
	EQUB LO(NMI6_READ_toMem)

	\\ Ditto (high bytes)
.NMI_Table2
	EQUB HI(NMI01_READWRITE)
	EQUB HI(NMI01_READWRITE)
	EQUB HI(NMI2_DONOTHING)
	EQUB HI(NMI3_WRITE_fromTube)
	EQUB HI(NMI4_WRITE_fromMem)
	EQUB HI(NMI5_READ_toTube)
	EQUB HI(NMI6_READ_toMem)

	\\ Length of code - 1
.NMI_Table3
	EQUB  &4D, &4D, &00, &0F, &1A, &0F, &1A
ENDIF

	\\ GBPB tables
.gbpbv_table1
	EQUB LO(gbpbv0_donothing)
	EQUB LO(gbpb_putbytes)
	EQUB LO(gbpb_putbytes)
	EQUB LO(gbpb_getbyte_SAVEBYTE)
	EQUB LO(gbpb_getbyte_SAVEBYTE)
	EQUB LO(gbpb5_getmediatitle)
	EQUB LO(gbpb6_rdcurdir_device)
	EQUB LO(gbpb7_rdcurlib_device)
	EQUB LO(gbpb8_rdfilescurdir)

.gbpbv_table2
	EQUB HI(gbpbv0_donothing)
	EQUB HI(gbpb_putbytes)
	EQUB HI(gbpb_putbytes)
	EQUB HI(gbpb_getbyte_SAVEBYTE)
	EQUB HI(gbpb_getbyte_SAVEBYTE)
	EQUB HI(gbpb5_getmediatitle)
	EQUB HI(gbpb6_rdcurdir_device)
	EQUB HI(gbpb7_rdcurlib_device)
	EQUB HI(gbpb8_rdfilescurdir)

.gbpbv_table3
	EQUB &04, &02, &03, &06, &07, &04, &04, &04, &04

IF sys=226
	INCLUDE "filesys_random.asm"
ENDIF

IF ultra
.CMD_DUTILS
	TYA				;*HELP DUTILS
	LDX #cmdtab4+2
	LDY #cmdtable4_count
	SEC
	BCS prthelpTabC			;always
ENDIF

.CMD_DFS
	TYA 				;*HELP DFS
	LDX #cmdtab1+2			;cmd table 1
	LDY #cmdtable1_count		;Number of commands

	\ Print help
	\ X = offset of command table
	\ Y = number of commands
	\ For ultra, C = 0 for table1... else table4...
.prthelp
IF ultra
	CLC

.prthelpTabC
ENDIF
{
IF ultra
	ROR cmdtab_flag			;Bit 7 = C
ENDIF

	PHA 
	JSR PrtString
	EQUS 13

IF ultra
	EQUS "Ultra "
ENDIF

	EQUS "DFS "

IF sys=120
	EQUS "1.20"
ELIF sys=224
	EQUS "2.24"
ELSE
	EQUS "2.26"
ENDIF
	EQUB 13

	STX LastCommand

IF sys>120 OR ultra
	STY &B7				;\ ?&B7 = command counter
ENDIF

.help_dfs_loop
	LDA #&00
	STA &B9				;?&B9=0=print command (not error)

IF sys>120 OR ultra
	LDY #&02
	JSR prtcmd_PrintYSpaces		;print "  ";
ELSE
	JSR Prt2spaces			;print "  ";
ENDIF

	JSR prtcmdBC			;print cmd & parameters
	JSR prtNewLine			;print

IF sys>120 OR ultra
	DEC &B7	
ELSE
	DEY
ENDIF

	BNE help_dfs_loop

	PLA 				;restore Y
	TAY
}

.morehelp
	LDX #cmdtab3			;more? Eg *HELP DFS UTILS
	JMP UnrecCommandTextPointerX	;start cmd @ A3 in table

.CMD_UTILS
	TYA 				;*HELP UTILS
	LDX #cmdtab2+2			;cmd table 2
	LDY #cmdtable2_count
	BNE prthelp			;always

.CMD_NOTHELPTBL
{
	JSR GSINIT_A
IF ultra
	BNE cmd_nothelptbl_loop

	RTS
ELSE
	BEQ prtcmdparamexit		;null str
ENDIF

.cmd_nothelptbl_loop
	JSR GSREAD_A
	BCC cmd_nothelptbl_loop		;if not end of str
	BCS morehelp			;always
}

.Param_SyntaxErrorIfNull
	JSR GSINIT_A			;(if no params then syntax error)
	BNE prtcmdparamexit		;branch if not null string

.errSYNTAX
	JSR ReportError_start		;Print Syntax error
	EQUS &DC, "Syntax: "

	STX &B9				;?&B9=&100 offset (>0)
	JSR prtcmdBC			;add command syntax

	LDA #&00
	JSR prtcmd_prtchr
	JMP &0100			;Cause BREAK!

.prtcmdBC
{
	LDX LastCommand			;X=table offset

IF sys>120 OR ultra
	LDA #9				;\ Column width = 9
	STA &B8				;\ Parameters aligned
ENDIF

.prtcmdloop
IF ultra
	JSR cmdtab_getchr
ELSE
	INX 				;If ?&B9=0 then print
	LDA cmdlist,X			;else it’s the &100 offset
ENDIF
	BMI prtcmdloop_exit		;If end of str

	JSR prtcmd_prtchr
	JMP prtcmdloop

.prtcmdloop_exit
IF sys>120 OR ultra
	LDY &B8				;\
	CPY #&0C			;\ Y never = &0c ??????
	BEQ prtcmdnospcs		;\

	JSR prtcmd_PrintYSpaces		;\ print spaces

.prtcmdnospcs
ENDIF
	INX 				;skip address
	INX
	STX LastCommand			;ready for next time

IF ultra
	JSR cmdtab_getchr2
ELSE
	LDA cmdlist,X			;paramater code
ENDIF
	JSR prtcmdparam			;1st parameter
	JSR Alsr4			;2nd parameter

.prtcmdparam
	JSR rememberAXY
	AND #&0F
	BEQ prtcmdparamexit		;no parameter

	TAY 				;Y=parameter no.

IF ultra
	BIT cmdtab_flag			;Y+=1 if DUTILS parameter
	BPL skip			;(to allow for more than 15 parameters)

	INY

.skip
ENDIF
	LDA #&20
	JSR prtcmd_prtchr		;print space

	LDX #&FF			;Got to parameter Y

.prtcmdparam_findloop
	INX 				;(Each param starts with
	LDA parametertable,X		;bit 7 set)
	BPL prtcmdparam_findloop

	DEY 
	BNE prtcmdparam_findloop	;next parameter

	AND #&7F			;Clear bit 7 of first chr

.prtcmdparam_loop
	JSR prtcmd_prtchr		;Print parameter
	INX 
	LDA parametertable,X
	BPL prtcmdparam_loop

	RTS
}

.prtcmd_prtchr
	JSR rememberAXY			;Print chr
	LDX &B9
	BEQ prtcmdparam_prtchr		;If printing help

	INC &B9
	STA &0100,X

.prtcmdparamexit
	RTS


.prtcmdparam_prtchr
IF sys>120 OR ultra
	DEC &B8				;\ If help print chr
	JMP PrtChrA

.prtcmd_PrintYSpaces
{
	LDA &B9				;\
	BNE prtcmd_yspc_exit		;\ If printer error exit

	LDA #&20			;\ Print space

.prtcmd_yspc_loop
	JSR prtcmd_prtchr		;\
	DEY 				;\
	BNE prtcmd_yspc_loop		;\

.prtcmd_yspc_exit
	RTS
}
ELSE
	JMP PrtChrA
ENDIF

.parametertable
IF ultra
	_afsp_=1
	_fsp_=2
	EQUB '<' OR &80, "afsp>"		;1(-1 for DUTILS)
ENDIF
	EQUB '<' OR &80, "fsp>"			;1/2(1)
IF NOT(ultra)
	_afsp_=2
	_fsp_=1
	EQUB '<' OR &80, "afsp>"		;2
ENDIF
	EQUB '(' OR &80, "L)"			;3
	EQUB '<' OR &80, "source> <dest.>"	;4
	EQUB '<' OR &80, "old fsp> <new fsp>"	;5
	EQUB '(' OR &80, "<dir>)"		;6
	EQUB '(' OR &80, "<drive>)"		;7(6)
	EQUB '<' OR &80, "title>"		;8
IF sys=120 AND NOT(ultra)
	EQUB '<' OR &80, "drive>"		;9
ELSE
	EQUB '<' OR &80, "drive>"
IF sys>120
	EQUS " (40)(80)"
ENDIF
	EQUB '4' OR &80, "0/80"			;10
	EQUB '(' OR &80, "<drive>)..."		;11
	EQUB '(' OR &80, "<rom>)"		;12(10)
ENDIF
IF ultra					;DUTILS parameters
	EQUS '<' OR &80, "drive>"		;13(11)
	EQUS '<' OR &80, "dno>/<dsp>"		;14(12)
	EQUS '<' OR &80, "dno>"			;15(13)
	EQUS '(' OR &80, "(<from dno>) <to dno>) (<adsp>)"	;16(14)
ENDIF
	EQUB 255

.CMD_COMPACT
{
	JSR Param_OptionalDriveNo
	JSR PrtString
	EQUS "Compacting :"
	STA SRC_DRIVE			;Source Drive No.
	STA DEST_DRIVE			;Dest Drive No.
	JSR prthexLoNib
	JSR prtNewLine
	LDY #&00
	JSR CloseFileY			;Close all files
	JSR CalcRAM
	JSR LoadCurDrvCat		;Load catalogue
	LDY FilesX8
	STY &CA				;?CA=file offset
	LDA #&02
	STA &C8
	LDA #&00
	STA &C9				;word C8=next free sector

.compact_loop
	LDY &CA
	JSR Yless8
	CPY #&F8
	BNE compact_checkfile		;If not end of catalogue

	LDA swsp+&0F07			;Calc & print no. free sectors
	SEC 				;(disk sectors - word C8)
	SBC &C8
	PHA 
	LDA swsp+&0F06
	AND #&03
	SBC &C9
	JSR prthexLoNib
	PLA 
	JSR PrtHexA
	JSR PrtString
	EQUS " free sectors", 13
	NOP
	RTS 
				;Finished compacting
.compact_checkfile
	STY &CA				;Y=cat offset
	JSR prt_InfoMsgY		;Only if messages on
	LDY &CA				;Y preserved?
	LDA swsp+&0F0C,Y		;A=Len0
	CMP #&01			;C=sec count
	LDA #&00
	STA &BC
	STA &C0
	ADC swsp+&0F0D,Y		;A=Len1
	STA &C4
	LDA swsp+&0F0E,Y
	PHP 
	JSR Alsr4and3			;A=Len2
	PLP 
	ADC #&00
	STA &C5				;word C4=size in sectors
	LDA swsp+&0F0F,Y		;A=sec0
	STA &C6
	LDA swsp+&0F0E,Y
	AND #&03			;A=sec1
	STA &C7				;word C6=sector
	CMP &C9				;word C6=word C8?
	BNE compact_movefile		;If no

	LDA &C6
	CMP &C8
	BNE compact_movefile		;If no

	CLC 
	ADC &C4
	STA &C8
	LDA &C9
	ADC &C5
	STA &C9				;word C8 += word C4
	JMP compact_fileinfo

.compact_movefile
	LDA &C8				;Move file
	STA swsp+&0F0F,Y		;Change start sec in catalogue
	LDA swsp+&0F0E,Y		;to word C8
	AND #&FC
	ORA &C9
	STA swsp+&0F0E,Y
	LDA #&00
	STA &A8				;Don't create file
	STA &A9
	JSR CopyDATABLOCK		;Move file
	JSR SaveCatToDisk		;Save catalogue

.compact_fileinfo
	LDY &CA
	JSR prt_InfoLineY
	JMP compact_loop
}

.IsEnabledOrGo
{
	BIT CMDEnabledIf1
	BPL isgoalready
	JSR GoYN
	BEQ isgo

	PLA 				;don't return to sub
	PLA 

.isgo
	JMP prtNewLine
}

.Get_CopyDATA_Drives
{
	JSR Param_SyntaxErrorIfNull	;Get drives & calc ram & msg
	JSR Param_DriveNo_BadDrive
	STA SRC_DRIVE			;Source drive

	JSR Param_SyntaxErrorIfNull
	JSR Param_DriveNo_BadDrive
	STA DEST_DRIVE			;Destination drive
	TYA 
	PHA 
	LDA #&00
	STA &A9
	LDA DEST_DRIVE
	CMP SRC_DRIVE
	BNE gcdd_samedrive		;If not same drive

	LDA #&FF			;SOURCE <> DEST
	STA &A9
	STA &AA

.gcdd_samedrive
	JSR CalcRAM			; Calc ram available
	JSR PrtString
	EQUS "Copying from :"
	LDA SRC_DRIVE
	JSR prthexLoNib
	JSR PrtString
	EQUS " to :"
	LDA DEST_DRIVE
	JSR prthexLoNib
	JSR prtNewLine
	PLA
	TAY
	CLC
}
.isgoalready
	RTS 

.PromptInsertSourceDisk
	JSR rememberAXY			;If ?A9 +ve = same drive
	BIT &A9
	BPL insdisk_done		;If SOURCE <> DEST exit

	LDA #&00			;prompt for SOURCE
	BEQ insdisk_prompt		;always

.PromptInsertDestDisk
	JSR rememberAXY
	BIT &A9
	BMI insdisk_destdisk		;If SOURCE = DEST

.insdisk_done
	RTS

.insdisk_destdisk
	LDA #&80

.insdisk_prompt
{
	CMP &AA				; Is disk already in?
	BEQ insdisk_done		; If yes

	STA &AA				; If ?AA +ve = SOURCE
	JSR PrtString
	EQUS "Insert "
	NOP
	BIT &AA
	BMI msg_Destination		; If dest drive

	JSR PrtString
	EQUS "source"
	BCC msg_DiskAndHitAKey		; always

.msg_Destination
	JSR PrtString
	EQUS "destination"
	NOP

.msg_DiskAndHitAKey
	JSR PrtString
IF sys>120 OR ultra
	EQUS " disc"
ELSE
	EQUS " disk"
ENDIF
	EQUS " and hit a key"
	NOP
	JSR osbyte0FA
	JSR OSRDCH			; Wait for key press
	BCS err_ESCAPE			; If ESCAPE pressed
}

.prtNewLine
	PHA 
	LDA #&0D
	JSR PrtChrA
	PLA 
	RTS 

IF sys>120
.ConfirmYN
	JSR PrtString
	EQUS " : "
	BCC ConfirmYN2
ENDIF

.GoYN
	JSR PrtString
	EQUS "Go (Y/N) ? "
	NOP

IF sys=120
.ConfirmYN
ELSE
.ConfirmYN2
ENDIF
{
	JSR osbyte0FA
	JSR OSRDCH			;Get chr
	BCS err_ESCAPE			;If ESCAPE

	AND #&5F
	CMP #&59			;"Y"?
	PHP 
	BEQ confYN

	LDA #&4E			;"N"

.confYN
	JSR PrtChrA
	PLP 
	RTS
}
 
.err_ESCAPE
	JMP reportESCAPE

.err_DISKFULL2
	JMP errDISKFULL

.CMD_BACKUP
{
	JSR Get_CopyDATA_Drives
	JSR IsEnabledOrGo
	LDA #&00
	STA &C7
	STA &C9
	STA &C8
	STA &C6
	STA &A8				;Don’t' create file
	JSR PromptInsertSourceDisk
	LDA SRC_DRIVE
	STA CurrentDrv
	JSR LoadCurDrvCatalog
	LDA swsp+&0F07			;Size of source disk
	STA &C4				;Word C4 = size fo block
	LDA swsp+&0F06
	AND #&03
	STA &C5
	JSR PromptInsertDestDisk
	LDA DEST_DRIVE
	STA CurrentDrv
	JSR LoadCurDrvCatalog
	LDA swsp+&0F06			;Is dest disk smaller?
	AND #&03
	CMP &C5
	BCC err_DISKFULL2

	BNE backup_copy
	LDA swsp+&0F07
	CMP &C4
	BCC err_DISKFULL2

.backup_copy
	JSR CopyDATABLOCK
	JMP LoadCurDrvCatalog
}

.CMD_COPY
{
	JSR parameter_afsp
	JSR Get_CopyDATA_Drives
	JSR Param_SyntaxErrorIfNull
	JSR read_afspTextPointer
	JSR PromptInsertSourceDisk
	LDA SRC_DRIVE
	JSR SetCurrentDriveA
	JSR getcatentry

.copy_loop1
	LDA DirectoryParam
	PHA 
	LDA &B6
	STA &AB
	JSR prt_InfoLineY

	LDX #&00

.copy_loop2
	LDA swsp+&0E08,Y
	STA &C5,X
	STA VAL_1050,X
	LDA swsp+&0F08,Y
	STA &BB,X
	STA VAL_1047,X
	INX 
	INY 
	CPX #&08
	BNE copy_loop2

	LDA &C1
	JSR Alsr4and3
	STA &C3
	LDA &BF
	CLC 
	ADC #&FF
	LDA &C0
	ADC #&00
	STA &C4
	LDA &C3
	ADC #&00
	STA &C5
	LDA VAL_104E
	STA &C6
	LDA VAL_104D
	AND #&03
	STA &C7
	LDA #&FF
	STA &A8				;Create new file
	JSR CopyDATABLOCK
	JSR PromptInsertSourceDisk
	LDA SRC_DRIVE
	JSR SetCurrentDriveA
	JSR LoadCurDrvCat
	LDA &AB
	STA &B6
	PLA 
	STA DirectoryParam
	JSR get_cat_nextentry
	BCS copy_loop1

	RTS
}

.cd_writedest_cat
{
	JSR cd_swapvars			;Write to destination catalogue
	JSR PromptInsertDestDisk	;i.e. to create file
	LDA DEST_DRIVE
	STA CurrentDrv
	LDA DirectoryParam
	PHA 
	JSR LoadCurDrvCat		;Load cat
	JSR get_cat_entry80
	BCC cd_writedest_cat_nodel	;If file not found
	JSR DeleteCatEntryY

.cd_writedest_cat_nodel
	PLA 
	STA DirectoryParam
	JSR LoadAddrHi2
	JSR ExecAddrHi2
	LDA &C2				;mixed byte
	JSR Alsr4and3
	STA &C4
	JSR CreateFile_2		;Saves cat
	LDA &C2				;Remember sector
	AND #&03
	PHA 
	LDA &C3
	PHA 
	JSR cd_swapvars			;Back to source
	PLA 				;Next free sec on dest
	STA &C8
	PLA 
	STA &C9
	RTS 

.cd_swapvars
	LDX #&11			;Swap BA-CB & 1045-1056

.cd_swapvars_loop
	LDA VAL_1045,X			;I.e. src/dest
	LDY &BA,X
	STA &BA,X
	TYA 
	STA VAL_1045,X
	DEX 
	BPL cd_swapvars_loop

	RTS
}

.CopyDATABLOCK
{
	LDA #&00			;*** Move or copy sectors
	STA &BC				;Word &C4 = size of block
	STA &C0
	BEQ cd_loopentry		;always

.cd_loop
	LDA &C4
	TAY 
	CMP RAM_AVAILABLE		;Size of buffer
	LDA &C5
	SBC #&00
	BCC cd_part			;IF size<size of buffer

	LDY RAM_AVAILABLE

.cd_part
	STY &C1
	LDA &C6				;C2/C3 = Block start sector
	STA &C3				;Start sec = Word C6
	LDA &C7
	STA &C2
	LDA PAGE			;Buffer address
	STA &BD
	LDA SRC_DRIVE
	STA CurrentDrv
	JSR PromptInsertSourceDisk
	JSR SetLoadAddrToHost

IF sys=120
	JSR FDC_SetToCurrentDrv
ENDIF
	JSR LoadMemBlock
	LDA DEST_DRIVE
	STA CurrentDrv
	BIT &A8
	BPL cd_skipwrcat		;Don’t create file

	JSR cd_writedest_cat
	LDA #&00
	STA &A8				;File created!

.cd_skipwrcat
	LDA &C8				;C2/C3 = Block start sector
	STA &C3				;Start sec = Word C8
	LDA &C9
	STA &C2
	LDA PAGE			;Buffer address
	STA &BD
	JSR PromptInsertDestDisk
	JSR SetLoadAddrToHost
IF sys=120
	JSR FDC_SetToCurrentDrv
ENDIF
	JSR SaveMemBlock
	LDA &C1				;Word C8 += ?C1
	CLC 				;Dest sector start
	ADC &C8
	STA &C8
	BCC cd_inc1

	INC &C9

.cd_inc1
	LDA &C1				;Word C6 += ?C1
	CLC 				;Source sector start
	ADC &C6
	STA &C6

	BCC cd_inc2
	INC &C7

.cd_inc2
	SEC 				;Word C4 -= ?C1
	LDA &C4				;Sector counter
	SBC &C1
	STA &C4
	BCS cd_loopentry

	DEC &C5

.cd_loopentry
	LDA &C4
	ORA &C5
	BNE cd_loop			;If Word C4 <> 0

	RTS
}

IF sys>120				;Moved here!
.SetLoadAddrToHost
	LDA #&FF			;Set load address high bytes
	STA VAL_1074			;to FFFF (i.e. host)
	STA VAL_1075
	RTS
ENDIF

IF sys>120 or ultra
	INCLUDE "filesys_newcommands.asm"
ENDIF

\\END OF FILE
