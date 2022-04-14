	\\ Acorn DFS
	\\ filesys_newcommands.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

	\ Contains the new commands:
	\ *VERIFY
	\ *FORM
	\ *FREE
	\ *MAP
	\ *ROMS

.CMD_VERIFY
	LDA #&00			;\\\\\ *VERIFY
	BEQ vf_Drive

.CMD_FORM
	LDA #&FF			;\\\\\ *FORM
	STA LoadedCatDrive

	\ OWCtlBlock = &1090		;16 bytes
.vf_Drive
{
	attempts = OWCtlBlock+&D
	tracks = OWCtlBlock+&F

{
	STA &C9
	STA OWCtlBlock
	BPL label2			;If verifying

	JSR Param_SyntaxErrorIfNull	;Get number of tracks (40/80)

	JSR Decimal_TxtPtrToBinary
	STA tracks			;Number of tracks (to format)
	BCS label1

	CMP #35
	BEQ label2			;If =35

	CMP #40
	BEQ label2			;If =40

	CMP #80
	BEQ label2			;If =80

.label1	JMP errSYNTAX

.label2	JSR GSINIT_A
	STY &CA				;Save Y
	BNE loop5

	\ No drive param, so ask!

	BIT &C9
IF ultra				;Ultra uses bit 6
	BVS label3
ELSE
	BMI label3			;If formatting
ENDIF

	JSR PrtString
	EQUS "Verify"
	BCC label4			;always

.label3	JSR PrtString
	EQUS "Format"
	NOP 

.label4	JSR PrtString
	EQUS " which drive ? "
	NOP 
	JSR OSRDCH
	BCS jmp_reportEscape

	CMP #&20
	BCC jmp_errBadDrive

	JSR PrtChrA
	SEC 
	SBC #&30
	BCC jmp_errBadDrive

	CMP #4
	BCS jmp_errBadDrive		;If >=4

	STA ActiveDrv
	JSR prtNewLine

	LDY &CA				;Restore Y
	JMP label6

.loop5	JSR Param_DriveNo_BadDrive

.label6	STY &CA

IF ultra
	ROL &C9
	JSR MMC_ActiveDrv_State
	ROR &C9				;Bit 7 = virtual drv flag
ENDIF

IF sys>120
	BIT &C9
IF ultra
	BVC label7			;If verifying
	BMI label7			;Or if virtual disk
ELSE
	BPL label7			;If verifying
ENDIF

	LDX ActiveDrv
	LDA #&00
	STA DRIVE_MODE,X		;Reset drive mode

.label7
ENDIF

	\ Note: ?OWCtlBlock is set to drv number in vf_ActiveDrv
	\ subroutine, :. bit 7 clear after first call.
	BIT OWCtlBlock
	BPL label8			;If verifying or already done

	JSR IsEnabledOrGo
	JSR CalcRAM

.label8	JSR vf_ActiveDrv

	LDY &CA
	JSR GSINIT_A
	BNE loop5			;More drives?

	RTS
}

.jmp_reportEscape
	JMP reportESCAPE

.jmp_errBadDrive
	JMP errBADDRIVE


	\\ Verify / Format active drive

	\ Virtual drive:
	\ Drive must not be empty and
	\ if verifying then disk must be formatted, else
	\ if formatting then disk must be unformatted.
.vf_ActiveDrv
{

	BIT &C9
IF ultra
	BVS label1			;If formatting
ELSE
	BMI label1			;If formatting
ENDIF

	JSR PrtString
	EQUS "Verifying"
	BCC label2			;always NOTE: We skip setting ?OWCtlBlock=drive;
					;but this is done when catalogue read,
					;i.e. when SUB_93F5_rdCatalogue_81 called.

	\ Formatting

.label1
IF NOT(ultra)
	\ For ultra we do this later, because if it's a virtual disk
	\ we will use the catalogue memory for MMB disk table read & write to change
	\ disk state to formatted and clear the title.

	JSR vf_NewCatalogue
ENDIF

	JSR PrtString
	EQUS "Formatting"

IF ultra
	NOP
ELSE
	LDX ActiveDrv
	STX OWCtlBlock
ENDIF

.label2	JSR PrtString
	EQUS " drive "

	LDA ActiveDrv
IF ultra
	STA OWCtlBlock			;Need to do this when verifying too for 1.20.
ENDIF
	JSR prthexLoNib

	JSR PrtString
	EQUS " track   "
	NOP 

	BIT &C9
IF ultra
	BVS label4
ELSE
	BMI label4			;If formatting
ENDIF

	JSR vf_CalcTracksOnDisk
	TXA 
	BNE label3

	JMP prtNewLine

.label3	STA tracks 			;number of tracks

.label4	LDA #0
	STA OWCtlBlock+7		;track

.loop5	LDA #&08			;2 x backspaces
	JSR PrtChrA
	JSR PrtChrA

	LDA OWCtlBlock+7
	JSR PrtHexA			;print track

	LDA #6
	STA attempts			;try up to 5 times!

.loop6	JSR vf_PopOWBlock		;defaults to "format"

	BIT &C9
IF ultra
	BVC label7			;If verifying
ELSE
	BPL label7			;If verifying
ENDIF

	\ Format & verify track

	JSR vf_Build_Track_Data

	LDX #LO(OWCtlBlock)
	LDY #HI(OWCtlBlock)
	JSR Osword7F_8271_Emulation

	TAX 				;A=result
	BNE label8			;If error

IF ultra
	BIT &C9
	BMI label9			;If virtual don't verify format.
					;(The disk may be marked as unformatted,
					;so verifying would cause a fatal error!)
ENDIF

	\ Verify track

.label7	LDA #&00			;Modify param block
	STA OWCtlBlock+8		;sector

IF sys<>120
	LDA OWCtlBlock+9
	AND #&1F			;no.of sectors only
	STA OWCtlBlock+9
ENDIF

	LDA #3
	STA OWCtlBlock+5		;no.of parameters

	LDA #&5F
	STA OWCtlBlock+6		;8271 command &5F:
					;"Read data & deleted data"
	JSR CheckESCAPE

	LDX #LO(OWCtlBlock)
	LDY #HI(OWCtlBlock)
	JSR Osword7F_8271_Emulation
	BEQ label9			;If ok

	DEC attempts
	BNE loop6			;Try again!

	\ Format error, or too many verify errors.

.label8	JSR PrtString
	EQUS "?"
	NOP 
	JMP FDC_ReportDiskFault_A_fault	;Fatal

.label9	LDA attempts
	CMP #6
	BEQ label10			;If no error(s) occurred

	JSR PrtString
	EQUS "?   " 
	NOP 

.label10

IF NOT(ultra)
	BIT &C9
	BPL label11			;If verifying

	JSR vf_AddSectors		;Sector count +=10

.label11
ENDIF

	INC OWCtlBlock+7		;next track
	LDA OWCtlBlock+7
	CMP tracks			;more tracks?
	BNE loop5

	\ No more tracks to format/verify.

	BIT &C9
IF ultra
	BVC label12			;If verifying
	BPL lab_4			;If real

	JSR MMC_DiskFormatted		;Mark disk as formatted, and clear title.

.lab_4
	JSR vf_NewCatalogue

ELSE
	BPL label12			;If verifying
ENDIF

	\ Finish formatting by writing blank catalogue.

	JSR SaveCatToDisk_DontIncCycleNo	;Write blank catalogue

.label12
	JMP prtNewLine
}


	\ Populate OSWORD control block.
	\ (Default values are for formatting.)
.vf_PopOWBlock
IF NOT(ultra)
	LDX #&00			;Setup parameter block
	STX OWCtlBlock+1		;Data address = &FFFFxx00
	STX OWCtlBlock+&A		;Gap 5 size (bytes)
	DEX 
	STX OWCtlBlock+3
	STX OWCtlBlock+4
	LDA PAGE
	STA OWCtlBlock+2		;xx=PAGE
	LDA #&05
	STA OWCtlBlock+5		;5 parameters
	LDA #&63
	STA OWCtlBlock+6		;8271 command &63 = format track
	LDA #&2A			;001-01010  1-10
	STA OWCtlBlock+9		;Size/No.of sectors (1=256,10/trk)
	LDX #&10
	LDY #&13			;Note: Disc based format command has Gap 3 = &10
	STX OWCtlBlock+&B		;Gap 1 size (bytes)
	STY OWCtlBlock+8		;Gap 3 size (bytes)
	RTS ;11*3+6*2+1=44
ELSE
{
	LDX #11

.loop1	CPX #7
	BEQ label2			;Don't overwrite track number.

	LDA data3-1,X
	STA OWCtlBlock,X

.label2	DEX
	BNE loop1

	LDA PAGE
	STA OWCtlBlock+2
	RTS ;4*3+4*2+1+11=32

.data3	EQUB &00, &00, &FF, &FF, &05, &63, &00, &13, &2A, &00, &10
}
ENDIF


.vf_NewCatalogue
{
	LDA #&00
	TAY 

.loop1	STA swsp+&0E00,Y
	STA swsp+&0F00,Y
	INY 
	BNE loop1

IF ultra
	LDY tracks			; Pop number of sectors

.loop2	LDA #&0A
	CLC
	ADC swsp+&0F07
	STA swsp+&0F07
	BCC label3

	INC swsp+&0F06

.label3	DEY
	BNE loop2
ENDIF 

	RTS
}

IF NOT(ultra)
	\\ Catalogue Sector Count +=10
.vf_AddSectors
{
	LDA #&0A
	CLC 
	ADC swsp+&0F07
	STA swsp+&0F07
	BCC label1

	INC swsp+&0F06

.label1	RTS
}
ENDIF

	\\ Build the data to be written to track (FORMAT)
	\\ First byte at PAGE.
.vf_Build_Track_Data
{
	LDA #&00			;SECTOR IDs for Formatting
	STA &B0				;B0 -> PAGE
	LDA PAGE
	STA &B1

	LDA #&0A
	STA &B2				;B2 = loop counter

	LDA OWCtlBlock+7		;track
	BEQ label1			;IF track=0

	LDY #&02
	LDA (&B0),Y
	CLC 
	ADC #&07			;stagger sector?
	JSR SUB_A7C5_X_A_MOD_10

.label1	TAX 				;X=sector
	LDY #&00

.loop2	LDA OWCtlBlock+7		;track
	STA (&B0),Y
	INY 
	LDA #&00			;0
	STA (&B0),Y
	INY 
	TXA 				;sector
	STA (&B0),Y
	INY 
	LDA #&01			;1
	STA (&B0),Y
	INY 
	INX 
	JSR SUB_A7C4_X_X_MOD_10
	DEC &B2
	BNE loop2

	RTS
}


.SUB_A7C4_X_X_MOD_10
	TXA 

.SUB_A7C5_X_A_MOD_10
{
	SEC 

.loop1	SBC #&0A
	BCS loop1

	ADC #&0A
	TAX 
	RTS
}


	\ Calc nor of tracks on disk (VERIFY)
	\ Exit: X=number of tracks
.vf_CalcTracksOnDisk
{
IF sys=120
	JSR LoadCurDrvCatalog
ELSE
	JSR SUB_93F5_rdCatalogue_81	;Load catalogue
ENDIF

	LDA swsp+&0F06			;Size of disk
	AND #&03
	TAX 
	LDA swsp+&0F07
	LDY #&0A			;10 sectors/track
	STY &B0
	LDY #&FF			;Calc number of tracks

.loop1	SEC 

.loop2	INY 
	SBC &B0
	BCS loop2

	DEX 
	BPL loop1

	ADC &B0
	PHA 
	TYA 
	TAX 
	PLA 
	BEQ label3

	INX 

.label3	RTS
}
};End of verify/format routines

IF NOT(ultra)
.CMD_FREE
	SEC 				;\\\\\\\\\ *FREE
	BCS Label_A7F7

.CMD_MAP
	CLC	 			;\\\\\\\\\ *MAP

.Label_A7F7
{
	ROR &C6
	JSR Param_OptionalDriveNo
	JSR LoadCurDrvCat
	BIT &C6
	BMI Label_A818_free		;If *FREE

	JSR PrintStringP
	EQUS "Address :  Length", 13

.Label_A818_free
	LDA swsp+&0F06
	AND #&03
	STA &C5
	STA &C2
	LDA swsp+&0F07
	STA &C4				;wC4=sector count
	SEC 
	SBC #&02			;wC1=sector count - 2 (map length)
	STA &C1
	BCS Label_A82F

	DEC &C2

.Label_A82F
	LDA #&02
	STA &BB				;wBB = 0002 (map address)
	LDA #&00			;wBF = 0000
	STA &BC
	STA &BF
	STA &C0
	LDA FilesX8
	AND #&F8
	TAY 
	BEQ Label_A86B_nofiles		;If no files
	BNE Label_A856_fileloop_entry	;always

.Label_A845_fileloop
	JSR Sub_A8E2_nextblock
	JSR Yless8			;Y -> next file
	LDA &C4
	SEC 
	SBC &BB
	LDA &C5
	SBC &BC
	BCC Label_A86B_nofiles

.Label_A856_fileloop_entry
	LDA swsp+&0F07,Y		;wC1 = File Start Sec - Map addr
	SEC 
	SBC &BB
	STA &C1
	PHP 
	LDA swsp+&0F06,Y
	AND #&03
	PLP 
	SBC &BC
	STA &C2
	BCC Label_A845_fileloop

.Label_A86B_nofiles
	STY &BD
	BIT &C6
	BMI Label_A87A_free		;If *FREE

	LDA &C1				;MAP only
	ORA &C2
	BEQ Label_A87A_free		;If wC1=0

	JSR Map_Address_Length

.Label_A87A_free
	LDA &C1
	CLC 
	ADC &BF
	STA &BF
	LDA &C2
	ADC &C0
	STA &C0
	LDY &BD
	BNE Label_A845_fileloop

	BIT &C6
	BPL Label_A8BD_rst		;If *MAP

	TAY 
	LDX &BF
	LDA #&F8
	SEC 
	SBC FilesX8
	JSR Sub_A90D_freeinfo
	JSR PrintStringP
	EQUS "Free", 13
	LDA &C4
	SEC 
	SBC &BF
	TAX 
	LDA &C5
	SBC &C0
	TAY 
	LDA FilesX8
	JSR Sub_A90D_freeinfo
	JSR PrintStringP
	EQUS "Used", 13
	NOP 

.Label_A8BD_rst
	RTS
}

.Map_Address_Length
	LDA &BC				;Print address (3 dig hex)
	JSR PrintNibble			;(*MAP only)
	LDA &BB
	JSR PrintHex2
	JSR PrintStringP
	EQUS "     :  "
	LDA &C2				;Print length (3 dig hex)
	JSR PrintNibble
	LDA &C1
	JSR PrintHex2
	LDA #&0D
	JSR OSASCI

.Sub_A8E2_nextblock
{
	LDA swsp+&0F06,Y		;wBB = start sec + len
	PHA 
	JSR Alsr4and3
	STA &BC
	PLA 
	AND #&03
	CLC 
	ADC &BC
	STA &BC
	LDA swsp+&0F04,Y
	BEQ Label_A8FA

	LDA #&01

.Label_A8FA
	CLC 
	ADC FilesX8,Y
	BCC Label_A902

	INC &BC

.Label_A902
	CLC 
	ADC swsp+&0F07,Y
	STA &BB
	BCC Label_A90C

	INC &BC

.Label_A90C
	RTS
}

.Sub_A90D_freeinfo
{
	JSR Alsr3			;*FREE line
	JSR PrintBCD2			;A = Number of files
	JSR PrintStringP
	EQUS " Files "
	STX &BC				;YX = Number of sectors
	STY &BD
	TYA 
	JSR PrintNibble
	TXA 
	JSR PrintHex2
	JSR PrintStringP
	EQUS " Sectors " 
	LDA #&00
	STA &BB
	STA &BE				;!BB = number of sectors * 256
	LDX #&1F			;i.e. !BB = number of bytes
	STX &C1				;Convert to decimal string
	LDX #&09

.Label_A941_loop1
	STA VAL_1000,X			;?1000 - ?1009 = 0
	DEX 
	BPL Label_A941_loop1

.Label_A947_loop2
	ASL &BB				;!BB = !BB * 2
	ROL &BC
	ROL &BD
	ROL &BE
	LDX #&00
	LDY #&09			;A=0

.Label_A953_loop3
	LDA VAL_1000,X
	ROL A
	CMP #&0A
	BCC Label_A95D			;If <10

	SBC #&0A

.Label_A95D
	STA VAL_1000,X
	INX 
	DEY 
	BPL Label_A953_loop3

	DEC &C1
	BPL Label_A947_loop2

	LDY #&20			;Print decimal string
	LDX #&05

.Label_A96C_loop4
	BNE Label_A970

	LDY #&2C

.Label_A970
	LDA VAL_1000,X
	BNE Label_A97D

	CPY #&2C
	BEQ Label_A97D

	LDA #&20
	BNE Label_A982			;always

.Label_A97D
	LDY #&2C
	CLC 
	ADC #&30

.Label_A982
	JSR OSASCI
	CPX #&03
	BNE Label_A98D

	TYA 
	JSR OSASCI			;Print " " or ","

.Label_A98D
	DEX 
	BPL Label_A96C_loop4

	JSR PrintStringP
	EQUS " Bytes "
	NOP 
	RTS
}

.PrintStringP
{
	STA &B3				;Save A
	PLA 				;Pull calling address
	STA &AE
	PLA 
	STA &AF
	LDA &B3				;Save A & Y
	PHA 
	TYA 
	PHA 
	LDY #&00

.Label_A9AB_loop
	JSR inc_word_AE
	LDA (&AE),Y
	BMI Label_A9B8_exloop

	JSR OSASCI
	JMP Label_A9AB_loop

.Label_A9B8_exloop
	PLA 
	TAY 
	PLA 
	CLC 
	JMP (&00AE)
}

.PrintBCD2
	JSR BinaryToBCD

.PrintHex2
	PHA 
	JSR Alsr4
	JSR PrintNibble
	PLA 

.PrintNibble
	JSR prthexnibcalc
	JMP OSASCI
ENDIF

IF sys<>224 ;AND NOT(ultra)
.CMD_ROMS
{
	LDA #&00			; *ROMS (<rom>)
	STA &A8
	JSR Sub_AAEA_StackAZero		;Change value of A in stack to 0?
	LDA #&0F
	STA &AA
	JSR RomTablePtrBA
	SEC 
	JSR GSINIT
	STY &AB
	CLC 
	BEQ Label_A9FF_notnum		;If null str (no parameter)

.Label_A9E7_loop
	JSR Decimal_TxtPtrToBinary
	BCS Label_A9FF_notnum		;If not number

	STY &AB				;Save Y
	AND #&0F
	STA &AA				;Rom Nr
	JSR Label_AA53_RomInfo
	LDY &AB
	JSR GSINIT_A
	STY &AB				;Restore Y
	BNE Label_A9E7_loop		;Another rom id?

	RTS

.Label_A9FF_notnum
	ROR &A8				;Loop through roms

.Label_AA01_loop
	BIT &A8
	BPL Label_AA0A

	JSR ROMtitlecompare		;Match title with parameter
	BCC Label_AA0D_nomatch

.Label_AA0A
	JSR Label_AA53_RomInfo

.Label_AA0D_nomatch
	DEC &AA
	BPL Label_AA01_loop

	RTS

.ROMtitlecompare
	LDA #&09			;wF6=&8009 = title
	STA &F6
	LDA #&80
	STA &F7
	LDY &AB

.Label_AA1C_loop
	LDA (TextPointer),Y
	CMP #&0D			;If end of str
	BEQ Label_AA44

	CMP #&22
	BEQ Label_AA44			;If ="."

	INY 
	CMP #&2A
	BEQ Label_AA51_match		;If ="*"

	JSR UcaseA
	STA &AE
	JSR ReadRomByte
	BEQ Label_AA42_nomatch

	LDX &AE
	CPX #&23			;"#"
	BEQ Label_AA1C_loop

	JSR UcaseA
	CMP &AE
	BEQ Label_AA1C_loop

.Label_AA42_nomatch
	CLC 
	RTS

.Label_AA44
	JSR ReadRomByte
	BEQ Label_AA51_match

	CMP #&20
	BEQ Label_AA44			;If =" "   skip spaces

	CMP #&0D
	BNE Label_AA42_nomatch		;If <>CR

.Label_AA51_match
	SEC 
	RTS

.Label_AA53_RomInfo
	LDY &AA				;Y=Rom nr
	LDA (&B4),Y
	BEQ Label_AA42_nomatch		;If RomTable(Y)=0

	PHA 
	JSR PrtString
	EQUS "Rom "
	TYA 
	JSR PrtBcdA			;Print ROM nr
	JSR PrtString
	EQUS " : "
	LDA #&28			;A="("
	JSR PrtChrA
	PLA 
	PHA 
	BMI Label_AA78			;Bit 7 set = Service Entry

	LDY #&20			;Y=" "
	BNE Label_AA7A			;always

.Label_AA78
	LDY #&53			;Y="S"

.Label_AA7A
	TYA 
	JSR PrtChrA
	PLA 
	LDY #&20			;Y=" "
	ASL A
	BPL Label_AA86			;Bit 6 set = Language Entry

	LDY #&4C			;Y="L"

.Label_AA86
	TYA 
	JSR PrtChrA
	LDA #&29			;A=")"
	JSR PrtChrA
	JSR Prtspace
	JSR PrtRomTitle
	JSR prtNewLine
	SEC 
	RTS

.PrtRomTitle
	LDA #&07			;Print ROM title
	STA &F6
	LDA #&80
	STA &F7				;wF6=&8007
	JSR ReadRomByte
	STA &AE				;Copyright offset
	INC &F6				;wF6=&8009
	LDY #&1E
	JSR PrintRomStr
	BCS Label_AAB7_rts		;If reached copyright offset

	JSR Prtspace
	DEY 
	JSR PrintRomStr

.Label_AAB7_rts
	RTS

.Label_AAB8_loop
	CMP #&20
	BCS Label_AABE			;If >=" "

	LDA #&20

.Label_AABE
	JSR PrtChrA
	DEY

.PrintRomStr
	LDA &F6
	CMP &AE
	BCS Label_AACE_rts		;If >=

	JSR ReadRomByte
	BNE Label_AAB8_loop
	CLC		 		;C=0=Terminator

.Label_AACE_rts
	RTS

.ReadRomByte
	TYA 				;Read byte from ROM
	PHA 
	LDY &AA
	JSR OSRDRM			;Address in wF6
	INC &F6
	TAX 
	PLA 
	TAY 
	TXA 
	RTS

.RomTablePtrBA
	JSR rememberXYonly
	LDA #&AA			;ROM information table @ XY
	JSR osbyteX00YFF
	STX &B4
	STY &B5
	RTS

.Sub_AAEA_StackAZero
	TSX 				;Change value of A to 0?
	LDA #&00
	STA swsp+&0107,X
	RTS
}
ENDIF


\\ End of file

