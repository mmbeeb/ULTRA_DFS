	\\ Acorn DFS
	\\ filesys_1770_part2.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather


.GetDiskDriveTimings
if sys=224
	LDA #&A1
	LDX #&0B
	JSR OSBYTE
	TYA
	AND #&02
	BEQ LABEL_8F45

	LDA #&03

.LABEL_8F45
else
	LDA #&FF			;Read startup options
	LDX #&00
	TAY 
	JSR OSBYTE
	TXA 
	LSR A
	LSR A
	LSR A
	LSR A
	AND #&03			;bits 4&5 = disk drive timings
endif
	STA NMI_Timings
	RTS

.SetupNMI1
{
	LDX #&5D			;Copy NMI routine 1 to &D00

.setupnmi1_copyloop1
	LDA NMI_ROUTINE1,X		;(8FD2 - 902F)
	STA NMIRoutine,X
	DEX 
	BPL setupnmi1_copyloop1

	LDX #&03
	BIT NMI_Flags

	BVC setupnmi1_notwrite		;If not cmd A0 or F0 (not writing)
	LDA #&4D

	STA &0D22			;(8FF4) L=4D (NMI1_9)
	LDX #&0E

.setupnmi1_copyloop2
	LDA NMI_ROUTINE1_SNIPPET-1,X
	STA &0D38,X			;(900A)
	DEX 
	BNE setupnmi1_copyloop2

.setupnmi1_notwrite
	BIT NMI_Flags
	BMI setupnmi1_tube		;If TUBE read/write

	LDY #&01
	LDA (&B0),Y			;M=Target address
	STA &0D3A,X
	INY 
	LDA (&B0),Y
	STA &0D3B,X
	RTS

.setupnmi1_tube
	LDA #&B0			;"D3F BCS NMI1_6"
	STA &0D3F			;i.e. don't do M=M+1
	LDA #&06
	STA &0D40
	RTS

.NMI_ROUTINE1
	PHA 				;D00 NMI ROUTINE
	LDA FDC_STATUS_COMMAND		;D01
	AND #&18			;D04 AND # MASK (@D05)
	CMP #&03			;D06 If Data Request & Busy
	BEQ NMI1_K2F_ReadWrite		;D08 BEQ K (addr = D08+2+K)

	AND #&FC			;D0A
	BNE NMI1_1			;D0C If 1 or 2 or 3?

	DEC NMI_SecCounter		;D0E Execution finished?
	BNE NMI1_2			;D10 If more sectors

.NMI1_1
	STA NMI_FDCresult		;D12
	PLA 				;D14
	RTI 				;D15

.NMI1_2
	LDA NMI_SecCounter		;D16 Is it the last sector?
	CMP #&01			;D18
	BNE NMI1_IncSector		;D1A

	LDA NMI_Flags			;D1C
	ROR A				;D1E
	BCC NMI1_IncSector		;D1F If bit 0 = 0 = Whole sector

	LDA #&48			;D21 LDA #L
	STA &0D4C			;D23 J=L

.NMI1_IncSector
	INC Sector			;D26
	LDA Sector			;D28

.NMI1_SetSector
	STA FDC_SECTOR			;D2A
	CMP FDC_SECTOR			;D2D
	BNE NMI1_SetSector		;D30

	LDA NMI_FDCcommand		;D32
	STA FDC_STATUS_COMMAND		;D34
	PLA 				;D37
	RTI 				;D38

.NMI1_K2F_ReadWrite
	LDA FDC_DATA			;* D39 (3) LDA FDC_DATA
	STA TUBE_R3_DATA		;* D3C STA TUBE_R3_DATA / M
	INC &0D3D			;* D3F M=M+1
	BNE NMI1_IncDataPtr		;* D42

	INC &0D3E			;* D44

.NMI1_IncDataPtr
	DEC NMI_ByteCounter		;D47
	BNE NMI1_MoreBytes		;D49 If more bytes

	LDA #&2F			;D4B LDA #J Reset for next call
	STA &0D09			;D4D K=J

.NMI1_MoreBytes
	PLA 				;D50
	RTI 				;D51

.NMI1_K48_IgnoreReadByte
	LDA FDC_DATA			;D52 Get A from FDC
	PLA 				;D55 Discard value
	RTI 				;D56

.NMI1_K4D_WriteZero
	LDA #&00			;D57 Send 0 to FDC
	STA FDC_DATA			;D59
	PLA 				;D5C
	RTI 				;D5D ** End of NMI routine 1

.NMI_ROUTINE1_SNIPPET
	LDA TUBE_R3_DATA		;* D39 LDA TUBE_R3_DATA / M
	STA FDC_DATA			;* D3C STA FDC_DATA
	INC &0D3A			;* D3F M=M+1
	BNE SetupNMI2_ReadOnly		;* D42 BNE [.NMI1_6]

	INC &0D3B			;* D44 ** End of snippet
}

.SetupNMI2_ReadOnly
{
	LDX &0D3D			;Copy NMI routine 2 to &D00
	LDA &0D3E			;(9067-90FA)
	PHA 				;AX=word &D3D=M in NMI1 routine
	LDY #&94

.setupnmi2_copyloop1
	LDA NMI_ROUTINE2-1,Y
	STA &0CFF,Y
	DEY 
	BNE setupnmi2_copyloop1

	PLA 
	BIT NMI_Flags
	BPL setupnmi2_nottube		;If not TUBE

	LDA #&B0			;"D18 BCS NMI2_K11"
	STA &0D18			;else M=AX
	LDA #&06
	STA &0D19
	RTS

.setupnmi2_nottube
	STX &0D16			;word &D16=AX
	STA &0D17
	RTS

.NMI_ROUTINE2 				;*** DD READ ROUTINE ***
	PHA 				;D00 Start of NMI routine 2
	LDA FDC_STATUS_COMMAND		;D01
	AND #&1B			;D04 AND # MASK (@D05)
	CMP #&03			;D06
	BNE NMI2_NotDataReq		;D08 If not (Data Request & Busy)

	LDA FDC_DATA			;D0A
	BCS NMI2_K26			;D0D BCS K (addr = D0D+2+K) always

.NMI2_NotDataReq
	AND #&FC			;D0F
	STA NMI_FDCresult		;D11 Save result
	PLA 				;D13
	RTI 				;D14

.NMI2_K06
	STA TUBE_R3_DATA		;D15 STA M
	INC &0D16			;D18 M = M + 1
	BNE NMI2_K11			;D1B

	INC &0D17			;D1D

.NMI2_K11
	DEC NMI_ByteCounter		;D20 B=word A6=byte counter
	BNE NMI2_K24			;D22 B=B-1

	DEC NMI_FDCcommand		;D24
	BNE NMI2_K24			;D26 IF B<>0

	LDA #&77			;D28 (K=&77)
	DEC NMI_SecCounter		;D2A
	BNE NMI2_SetK			;D2C If more sectors to be read

	LDA #&24			;D2E

.NMI2_SetK
	STA &0D0E			;D30 K=&24 Ignore any more DRQ's

.NMI2_K24
	PLA 				;D33
	RTI 				;D34

.NMI2_K26
	CMP #&FE			;D35 FE=ID Address Mark
	BEQ NMI2_6			;D37

	CMP #&CE			;D39 ?
	BNE NMI2_K24			;D3B

.NMI2_6
	LDA #&32			;D3D K=&32
	BNE NMI2_SetK			;D3F always

.NMI2_K32
	SBC FDC_DATA			;D41 Track!
	STA &B5				;D44
	LDA #&3B			;D46 K=&3B
	BNE NMI2_SetK			;D48 always

.NMI2_K3B
	LDA #&3F			;D4A K=&3F   Ignore Side
	BNE NMI2_SetK			;D4C always

.NMI2_K3F
	SBC Sector			;D4E Sector!
	ORA &B5				;D50
	STA &B5				;D52
	LDA #&49			;D54 K=&49
	BNE NMI2_SetK			;D56 always  Ignore Length

.NMI2_K49
	LDA #&4D			;D58 K=&4D
	BNE NMI2_SetK			;D5A always  Ignore ID CRC1

.NMI2_K4D
	LDA &B3				;D5C
	STA NMI_ByteCounter		;D5E
	LDA #&55			;D60 K=&55
	BNE NMI2_SetK			;D62 always  Ignore ID CRC2

.NMI2_K55
	LDA &B4				;D64
	STA NMI_FDCcommand		;D66 B=Sector Size in Bytes
	LDA #&5D			;D68 K=&5D
	BNE NMI2_SetK			;D6A always

.NMI2_K5D
	CMP #&FB			;D6C FB=Data Address Mark
	BEQ NMI2_7			;D6E
	CMP #&F8			;D70 F8=Deleted Data Addr Mark
	BNE NMI2_K24			;D72

.NMI2_7
	STA &B6				;D74 Save Mark
	LDA &B5				;D76 ?B5=0: Sector required!!!!
	BNE NMI2_8			;D78 If not sector wanted

	INC Sector			;D7A (Next Sector)
	LDA #&06			;D7C K=&06
	BNE NMI2_SetK			;D7E always  Start reading data

.NMI2_8
	INC NMI_SecCounter		;D80 Ignore sector
	LDA #&11			;D82
	BNE NMI2_SetK			;D84 always  Read/ignore sector

.NMI2_K77
	LDA #&7B			;D86 Ignore CRC1
	BNE NMI2_SetK			;D88 always

.NMI2_K7B
	LDA #&7F			;D8A Ignore CRC2
	BNE NMI2_SetK			;D8C always

.NMI2_K7F
	BNE NMI2_K24			;D8E
	LDA #&26			;D90 Ready for next sector
	BNE NMI2_SetK			;D92 ** END OF NMI_ROUTINE 2
}

.FDC_1770_SetSectorA
	STA FDC_SECTOR
	CMP FDC_SECTOR
	BNE FDC_1770_SetSectorA

	RTS

	\ Is FDC present?
	\ Exit: If C=1 then FDC is present.
.FDC_1770_CheckPresent
{
	LDX #&00
	LDA #&5A			;A=90

.fdcchk_loop
	STA FDC_TRACK
	CMP FDC_TRACK
	BEQ fdcchk_cont			;C=1

	DEX 
	BNE fdcchk_loop

.fdcchk_nofdc
	CLC 
	RTS 

.fdcchk_cont
	LDA FDC_DRIVECONTROL
	AND #&03			;Drive select
	BEQ fdcchk_nofdc

	RTS 				;C=1
}

.drvcontrol_table
if sys=226
	EQUB &29, &2A, &2D, &2E		;Drive Control settings
else
	EQUB &25, &26, &35, &36
endif

.fdccommands_table
	EQUB  &00, &10, &40, &50	;Recognised 1770 commands
	EQUB  &80, &81, &83, &A0	
	EQUB  &A1, &C0, &E0, &F0

.fdscommands_statusmasks
	EQUB  &18, &18, &18, &18	;Status Mask for command
	EQUB  &3F, &1F, &1F, &5F		
	EQUB  &5F, &17, &1B, &5F

.results1770
	EQUB  &08, &10, &18, &20, &40, &00	;Results for 1770

.results8271
	EQUB  &0E, &18, &0C, &20, &12, &00	;Equivalent 8271 results

.os7f_formattable
	EQUW os7f_formtable_sd		; single density
	EQUW os7f_formtable_dd		; double desnity

.os7f_formtable_dd
	EQUB  &3C, &0C, &03, &01, &01, &01, &01, &01	;format table: double density
	EQUB  &01, &16, &0C, &03, &01, &FF, &01, &01
	EQUB  &18, &04, &4E, &00, &F5, &FE, &00, &00
	EQUB  &00, &00, &F7, &4E, &00, &F5, &FB, &5A
	EQUB  &5A, &F7, &4E, &4E

.os7f_formtable_sd
	EQUB  &10, &06, &00, &01, &01, &01, &01, &01	;format table: sindle density
	EQUB  &01, &0B, &06, &00, &01, &FF, &01, &01
	EQUB  &13, &03, &FF, &00, &00, &FE, &00, &00
	EQUB  &00, &00, &F7, &FF, &00, &00, &FB, &E5
	EQUB  &E5, &F7, &FF, &FF

.os7F_8271cmdtable
	EQUB  &0A, &0B, &0E, &0F, &12, &13, &16, &17	;Recognised 8271 FDC commands
	EQUB  &1B, &1E, &1F, &23, &29, &20, &30

.os7F_1770cmdtable
	EQUB  &A0, &A0, &A1, &A1, &80, &80, &81, &81 	;Equivalent 1770 commands
	EQUB  &C0, &83, &83, &F0, &10, &E0, &F0

.Osword7F_8271_Emulation
{
IF ultra
	JSR MMC_OSWORD7F
ENDIF

	LDA #&FF			;OSWORD &7F
	STA LoadedCatDrive		;** 8271 Emulation **
	STX OWptr
	STY OWptr+1			;(C7)->Control Block 13 bytes
	LDY #&0C

.os7F_loop1
	LDA (OWptr),Y			;Copy control block to BA
	STA &00BA,Y
	DEY 
	BPL os7F_loop1

	LDX #&0C
	LDA &BF				;A=number of parameters
	CMP #&0A			;If &A allow cmds &20 / &30
	BNE os7F_lab1			;If no.params<>&A

	LDX #&0E			;X=table search range

.os7F_lab1
	LDA &C0				;A=8271 FDC command
	AND #&3F			;Clear drive bits
	CMP #&3A			;"Write Special Register"
	BEQ os7F_FDC8271_WrSpecReg

	CMP #&3D			;"Read Special Register"
	BEQ os7F_FDC8271_RdSpecReg

	CMP #&35			;"Initialise 8271/Load Bad Tracks"
	BNE os7F_loop2

	JMP os7F_FDC8271_BadTracks

.os7F_loop2
	CMP os7F_8271cmdtable,X		;Find command in table
	BEQ os7F_labXX2			;If found X=index

	DEX 
	BPL os7F_loop2

.os7F_ExitWithResult_FE
	LDA #&FE
	BMI os7F_ExitWithResultA	;always

.os7F_labXX2
	CMP #&23			;A=8271 command
	BEQ os7F_labXX3_Form		;If format track

	CPX #&04
	BCS os7F_labXX6_NotWrite	;If not write sector

.os7F_labXX3_Form
	LDA &BA				;Writing: Chk not 40 trk mode
	BPL os7F_labXX4_UseParamDrv	;If A=drive=-ve use current drive

	LDA CurrentDrv

.os7F_labXX4_UseParamDrv
	AND #&03
	TAY 				;Y=drive
	LDA DRIVE_MODE,Y		;A=drive mode
	BMI os7F_ExitWithResult_FE	;If 40 track mode exit A=FE

.os7F_labXX6_NotWrite
	LDY os7F_1770cmdtable,X		;Get 1770 command
	STY &C0				;Overwrite param block cmd
	CPY #&F0
	BNE os7F_labXX5_notForm		;If not write track "format"

	JSR OS7f_BuildFormatTable

.os7F_labXX5_notForm
	LDX #&BA
	LDY #&00			;YX->&00BA
	JSR EXECUTE_1770_OS7F_YX_addr

.os7F_ExitWithResultA
	PHA 				;A=result
	LDA &BF				;Store result in control block
	CLC 				;after last parameter
	ADC #&07
	TAY 
	PLA 
	STA (OWptr),Y
	RTS

.os7F_FDC8271_WrSpecReg
	JSR os7F_SurfaceBadTracks	;** "Write Special Register" **
	BCS Label_922B			;Else: Write Surface Bad Tracks

	LDA &C2				;Param 2 = track
	STA BAD_TRACKS,X
	BCC Label_923B			;always

.Label_922B
	JSR os7F_SurfaceCurrentTrack
	BCC os7F_goexit			;Else: Write Surface Current Track

	LDA &C2				;Param 2 = track
	LDY DRIVE_MODE,X
	BPL Label_9238			;If not 40 track mode

	ASL A				;Double stepping

.Label_9238
	STA CURRENT_TRACK,X

.Label_923B
	LDA #&00
	BEQ os7F_goexit			;always

.os7F_FDC8271_RdSpecReg
	JSR os7F_SurfaceBadTracks	;** "Read Special Register" **
	BCS os7F_9249			;If not Surface Bad Track!

	LDA BAD_TRACKS,X		;Read Surface Bad Tracks
	BCC os7F_goexit			;always

.os7F_9249
	JSR os7F_SurfaceCurrentTrack	;If C=1 X=0 OR 1
	BCC os7F_goexit

	LDA CURRENT_TRACK,X		;Read Surface Current Track
	LDY DRIVE_MODE,X
	BPL os7F_goexit			;If not 40 track mode

	LSR A				;Double stepping!

.os7F_goexit
	JMP os7F_ExitWithResultA

.os7F_FDC8271_BadTracks
	LDA #&FF			;** Initialise or Load Bad Tracks **
	LDX #&00
	LDY &C1				;Y=Param 1=surface (10/18)
	CPY #&10
	BEQ os7F_926A_surf0		;If Load Surface 0 Bad Tracks

	CPY #&18
	BNE os7F_9276_exit		;If not Load Surface 1 Bad Tracks

	INX 
	INX 				;X=2

.os7F_926A_surf0
	LDA &C2				;Param 2: Bad Track 1
	STA BAD_TRACKS,X
	LDA &C3				;Param 3: Bad Track 2
	STA BAD_TRACKS+1,X
	LDA #&00			;OK

.os7F_9276_exit
	JMP os7F_ExitWithResultA

.os7F_SurfaceCurrentTrack
	LDX #&00			;** Surface Current Track ? **
	LDA &C1				;A=Param 1=Reg.Addr
	CMP #&12			;Surface 0 Current Track X=0
	BEQ os7F_9289_rts

	INX 
	CMP #&1A			;Surface 1 Current Track X=1
	BEQ os7F_9289_rts

	LDA #&FE
	CLC 

.os7F_9289_rts
	RTS 				;X=surface if C=1

.os7F_SurfaceBadTracks
	LDA &C1				;** Surface Bad Tracks ? **
	AND #&F6			;A=Param 1=Reg.Addr
	CMP #&10			;Surface Bad Tracks?
	SEC 
	BNE os7f_929C_rts

	LDA &C1				;Bit3=Surface, Bit1=Track-1
	LSR A
	LSR A
	ORA &C1
	AND #&03			;A: bit 1=Surface, Bit 0=track-1
	TAX 

.os7f_929C_rts
	RTS
}

.OS7f_BuildFormatTable
{
	JSR CalcRAM			;Only called from 920A
	LDA &BB				;Command &F0 "Write Track"
	STA &B0				;BB/BC=memory address
	STA &B4				;of sector table
	CLC 
	ADC #&80			;word B0=addr
	STA &B2
	LDA &BC
	STA &B1
	PHP 
	JSR TUBE_CheckIfPresent
	BMI Label_92BD_notube		;If Tube not present

	LDA &BD				;addr hi bytes
IF ultra
	AND &BE
ELSE
	ORA &BE				;???? bug: AND &BE
ENDIF
	CMP #&FF
	BNE Label_92C4_nothost		;If addr in 2ndPro memory

.Label_92BD_notube
	LDA &B1				;If in host check >= PAGE
	CMP PAGE
	BCS Label_92C7			;If addr>=PAGE

.Label_92C4_nothost
	LDA PAGE			;PAGE: If 2ndPro or Addr<Page

.Label_92C7
	PLP 
	STA &B5
	ADC #&00			;memB0=addr
	STA &B3				;memB2=addr+&80 / *PAGE+&80
	INC &B5				;memB4=addr+&100 / *PAGE+&100
	LDA &BA				;A=drive (*offset by addr MOD&100)
	BPL Label_92D6

	LDA #&00

.Label_92D6
	ROL A
	ROL A
	ROL A				;bit 6 = drive bit 3 = DD
	STA VAL_108A
	LDX #&02
	ROL A
	BMI Label_92E3_dd		;If double density

	LDX #&00

.Label_92E3_dd
	LDA os7f_formattable,X		;Address of table
	STA &B6
	LDA os7f_formattable+1,X
	STA &B7
	LDY #&23

.Label_92EF_LOOP
	LDA (&B6),Y			;Copy table to memB2
	STA (&B2),Y
	DEY 
	BPL Label_92EF_LOOP

	\ This bit for sector length seems overly complicated!

	INY 
	STY &B6				;Y=0

	LDA &C3				;Sec Size/Per track
	PHA 
	AND #&E0			;A=sector size
	BNE Label_9302			;If not 128 bytes

	LDA #&10			;If > 128 bytes, always assume 256 bytes.

.Label_9302				;A=&00 or A=&10, ?&B6=0
	ASL A
	ROL &B6
	ASL A
	ROL &B6
	ASL A
	ROL &B6				;A=0, ?&B6=&00 or &01

	LDY #&0D
	STA (&B2),Y

	LDA &B6
	INY 
	STA (&B2),Y

	PLA 
	AND #&1F			;A=sectors per track
	STA &B9

	LDA &C2				;A=Gap 3 Size
	LDY #&10
	STA (&B2),Y

	LDA &C5				;A=Gap 1 Size
	LDY #&00
	STA (&B2),Y

	TYA 
	STA &B8				;A=0

	JSR SUB_93D3_apptab_A
	JSR TUBE_CheckIfPresent
	BMI Label_9367_notube

	LDA &BD
	AND &BE
	CMP #&FF
	BEQ Label_9367_notube

	LDA #&FF			;Read table into host memory
	STA &BD
	STA &BE
	JSR TUBE_CLAIM
	LDX #&BB
	LDY #&00			;Param block @ &00BB
	TYA 
	JSR TubeCode			;A=0=initrd
	LDX &B5				;memB0=memB4-&100 ie memB0=PAGE
	DEX 
	STX &B1
	LDA &B9				;A=sectors per track
	ASL A
	ASL A
	TAX 				;X=spt x 4 (4 bytes per sector)
	LDY #&00			;Read data from 2ndPro

.Label_9355_loop
	LDA #&07

.Label_9357_loop
	SBC #&01
	BNE Label_9357_loop		;idle

	LDA TUBE_R3_DATA
	STA (&B0),Y
	INY 
	DEX 
	BPL Label_9355_loop

	JSR TUBE_RELEASE_NoCheck	;Table copied!

.Label_9367_notube
	LDA &B5
	STA &BC				;memBB=memB4

.Label_936B_loop
	LDY #&16			;Copy 4 bytes
	LDX #&00

.Label_936F_loop
	LDA (&B0,X)
	STA (&B2),Y
	INC &B0
	BNE Label_9379

	INC &B1

.Label_9379
	INY 
	CPY #&1A
	BNE Label_936F_loop

	LDA #&01
	STA &B6

.Label_9382_loop
	LDA &B6
	CMP #&0E
	BNE Label_938D

	JSR SUB_93B4_apptab100_A
	BEQ Label_9390			;always

.Label_938D
	JSR SUB_93D3_apptab_A

.Label_9390
	INC &B6
	LDA &B6
	CMP #&11
	BNE Label_9382_loop

	INC &B8
	DEC &B9
	BNE Label_936B_loop

	TAY 
	LDA #&0E
	BIT VAL_108A
	BVC Label_93A8_sd		;If single density

	LDA #&1A

.Label_93A8_sd
	CLC 
	ADC &BC
	SBC &B5
	BCS Label_93B1

	LDA #&01

.Label_93B1
	STA (&B2),Y
	TYA 

.SUB_93B4_apptab100_A
	JSR SUB_93C5
	BEQ Label_93C4_RTS		;If X=0

	STX &B7
	LDX #&00			;X=0=&100

.Label_93BD_LOOP
	JSR SUB_93D8_apptab_A_Xbytes
	DEC &B7
	BNE Label_93BD_LOOP

.Label_93C4_RTS
	RTS

.SUB_93C5
	TAY 
	LDA (&B2),Y			;Y=A
	TAX 
	TYA 
	CLC 
	ADC #&12
	TAY 
	LDA (&B2),Y			;Y=Y+&12
	CPX #&00
	RTS

.SUB_93D3_apptab_A
	JSR SUB_93C5
	BEQ Label_93E5_RTS		;If X=0

.SUB_93D8_apptab_A_Xbytes
	LDY #&00			;X=count, A=value

.Label_93DA_LOOP
	STA (&B4),Y
	INC &B4
	BNE Label_93E2

	INC &B5

.Label_93E2
	DEX 
	BNE Label_93DA_LOOP

.Label_93E5_RTS
	RTS 		
}
