	\\ Acorn DFS
	\\ filesys_1770_part1.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather


.EXECUTE_1770_YX_addr
	CLC 
	BCC LABEL_8BFB			;always

.EXECUTE_1770_OS7F_YX_addr
	CLI 				;Enable interrupts
	SEC 				;(called only from 9211 OS7f)

.LABEL_8BFB
{
	ROR &B2				;Bit 7 = C
	STX &B0				;XY -> Parameter Block
	STY &B1
	CLD 
	JSR SETUP_1770_NMI_TUBE_SeekTrk0	;Seeks track 0 / Sets track
	LDA NMI_FDCresult
	BNE LABEL_8C12

	LDY #&05
	LDA (&B0),Y			;Number of parameters
	BEQ LABEL_8C12			;If =0

	JSR FDC_1770_Exec_ParamBlk_Cmd2	;Execute!

.LABEL_8C12
	LDY #&05
	LDA (&B0),Y			;Number of parameters
	CLC 
	ADC #&07
	TAY 
	LDA NMI_FDCresult
	JSR CONVERT_1770_RESULT
	STA (&B0),Y			;Save result to param block

if sys=226
	LDX NMI_FDCcommand
	CPX #&80
	BNE LABEL_8C2E			;If not read sector

	LDA FDC_STATUS_COMMAND
	AND #&20			;Data/Deleted Data?
	ORA (&B0),Y

.LABEL_8C2E
endif

	PHA
if sys=226
	AND #&DF			;1101 1111
endif
	CMP #&18
	BNE Label_8C3A			;If not 'Sector Not Found'

	LDA #&FF			;Reset flags
	STA VAL_1087

.Label_8C3A
	LDA CurrentDrv
	AND #&01
	TAY 
	LDA Track
	STA CURRENT_TRACK,Y		;Set surface Y current track
	JSR FDC_1770_SetTrack_A_track
	BIT NMI_Flags
	BPL Label_8C4E_nottube		;If not tube

	JSR TUBE_RELEASE_NoCheck

.Label_8C4E_nottube
	JSR NMI_RELEASE
	LDA FDC_DATA
	PLA		 		;A=RESULT (8271 style!)
	RTS
}

.CONVERT_1770_RESULT
{
	LDX #&05			;Convert result 1770 to 8271
.Label_8C58_LOOP
	CMP results1770,X
	BEQ Label_8C61_exit
	DEX 
	BPL Label_8C58_LOOP
	RTS 
.Label_8C61_exit
	LDA results8271,X
	RTS
}
 
.SETUP_1770_NMI_TUBE_SeekTrk0
{
	JSR NMI_CLAIM			;*** CLAIM NMI, ETC. ETC.
	JSR GetDiskDriveTimings
	LDA #&00
	STA NMI_Flags
	LDY #&09			;Sector Count + Bytes Last Sector

.Label_8C71
	LDA (&B0),Y			;Copy to B3-B5
	STA &00AA,Y			;B3/B4=Sector Counter +
	INY 				;B5=bytes in last sector
	CPY #&0C
	BNE Label_8C71

	LDY #&06
	LDA (&B0),Y			;A=command
	AND #&F0			;Clear low nibble
	CMP #&A0
	BEQ Label_8C87			;If Write Sector

	CMP #&F0			;(F0=Write Track)

.Label_8C87
	ROR NMI_Flags			;Bit 7 = cmd = &A0 or &F0
	LDY #&03			;Load Address bits 16-31
	LDA (&B0),Y
	INY 
	AND (&B0),Y
	CMP #&FF
	CLC 
	BEQ Label_8CB2			;IF to host

	JSR TUBE_CheckIfPresent
	CLC 
	BMI Label_8CB2			;If TUBE not present

	JSR TUBE_CLAIM
	LDA NMI_Flags
	ROL A				;C=bit 7
	ROL A				;bit 0=C
	AND #&01
	EOR #&01			;A=0=initrd, A=1=initwr
	LDX &B0				;XY=word B0 + 1
	LDY &B1
	INX 
	BNE Label_8CAE

	INY 

.Label_8CAE
	JSR TubeCode
	SEC 

.Label_8CB2
	ROR NMI_Flags			;bit 7=to TUBE
	JSR SetupNMI1			;Load NMI routine 1
	LDY #&00
	LDA (&B0),Y			;Drive, -ve = current drive
	BMI Label_8CC1

	AND #&0F
	STA CurrentDrv			;Allow DD

.Label_8CC1
	LDA CurrentDrv
	AND #&03
	TAX 
	LDA DRIVE_MODE,X		;Drive mode
	STA VAL_108A
	LDA CurrentDrv
	LDY #&0A			;Single D: 10 secs/trk
	AND #&08
	BEQ Label_8CD6			;If bit 3 clear (single density)

	LDY #&10			;Double D: 16 secs/trk

.Label_8CD6
	STY NMI_SecsPerTrk
	EOR drvcontrol_table,X
	STA FDC_DRIVECONTROL
	LSR A				;C=1=Drive 0
	LDX CURRENT_TRACK		;X=Current Track (Surf.0)
	BCS Label_8CE7			;IF Drive 0

	LDX CURRENT_TRACK+1		;X=Current Track (Surf.1)

.Label_8CE7
	LDY #&00			;Seek Track 0?
	STY NMI_FDCresult
	LDA VAL_1087			;Get flags
	BIT VAL_1087
	BCC Label_8CFC			;If Drive 1
	BPL Label_8D0D			;If bit 7 clr = already done

	STY CURRENT_TRACK			;Surf.0 Current Track = 0
	AND #&7F			;clr.bit 7 of flags
	BPL Label_8D03			;always

.Label_8CFC
	BVC Label_8D0D			;If bit 6 clr = already done
	STY CURRENT_TRACK+1		;Surf.1 Current Track = 0
	AND #&BF			;clr.bit 6 of flags

.Label_8D03
	STA VAL_1087			;Update flags
	LDA #&00
	JSR FDC_1770_ExecCommandA	;Restore (Seek track 0)
	LDX #&00

.Label_8D0D
	TXA 
	STA Track
	JSR FDC_1770_SetTrack_A_track
}
.execcmd2_rts
	RTS

.execcmd2_rdaddr
	JMP FDC_1770_ReadTrackAddress

.execcmd2_rwtrack
	JMP FDC_1770_ExecCommandA

.FDC_1770_Exec_ParamBlk_Cmd2
{
	JSR FDC_1770_Seek_ParamBlk_Track	;Seek track
	BNE execcmd2_rts		;If error exit!

	LDY #&06
	LDA (&B0),Y			;A=fdc 1770 cmd
	CMP #&10
	BEQ execcmd2_rts		;If seek : exit (already done!)

	CMP #&C0
	BEQ execcmd2_rdaddr		;If read address

	CMP #&E0
	BCS execcmd2_rwtrack		;If read/write track

	LDY #&08
	LDA (&B0),Y			;A=First Sector
	BIT &B2
	BMI execcmd2_osword7f_A_sector	;If call thru 8BF9 (osword7f)

	LDX &B5				;Bytes in last sector?
	BEQ execcmd2_trackloop

	INC &B3				;Add 1 to Sector Counter (SC)
	BNE execcmd2_trackloop

	INC &B4

.execcmd2_trackloop
	JSR FDC_1770_SetSectorA
	STA Sector			;A=first sector on this track
	SBC NMI_SecsPerTrk
	EOR #&FF
	CLC 
	ADC #&01
	STA NMI_SecCounter		;ST=Sec/Trk - First Sector
	LDA &B4
	BNE execcmd2_doit		;If SC>255

	LDA &B3
	BEQ execcmd2_exit		;If SC=0

	CMP NMI_SecCounter
	BEQ execcmd2_lastsec		;If SC<=ST
	BCS execcmd2_doit		;Else

.execcmd2_lastsec
	STA NMI_SecCounter		;Last sector on this track
	LDX &B5				;X=bytes in last sector
	BEQ execcmd2_doit		;If whole sectors only

	STX NMI_ByteCounter
	ROR NMI_Flags			;Set bit 0 of flags
	SEC 
	ROL NMI_Flags
	CMP #&01
	BNE execcmd2_doit		;If writing or Tube op.

	LDA &0D22
	STA &0D4C			;"J=L"

.execcmd2_doit
	LDA &B3
	SEC 				;SC = SC - ST
	SBC NMI_SecCounter
	STA &B3
	LDA &B4
	SBC #&00
	STA &B4
	JSR FDC_1770_Exec_ParamBlk_Cmd1	;EXECUTE!!!!
	BNE execcmd2_exit		;If error

	LDA &B3
	ORA &B4
	BEQ execcmd2_exit		;If Sector Counter=0

	JSR FDC_1770_StepIn
	BEQ execcmd2_trackloop		;If no error (also next Sector 0)

.execcmd2_exit
	RTS

.execcmd2_osword7f_A_sector
	JSR FDC_1770_SetSectorA		;Call indirectly from Osword7f
	STA Sector
	LDY #&09
	LDA (&B0),Y			;Sector Size/Sectors per Track
	AND #&1F
	BEQ execcmd2_exit		;If Sectors Per Track = 0

	STA NMI_SecCounter		;Number of sectors to read!
	BIT NMI_Flags
	BVS FDC_1770_Exec_ParamBlk_Cmd1		;If writing

	BIT VAL_108A			;Set at 92D9?????
	BVC FDC_1770_Exec_ParamBlk_Cmd1		;If not Special Read

	LDX #&33			;******* SPECIAL READ ******

.execcmd2_os7f_loop1
	LDA &0D60,X			;Save Mem: Copy D60-D93 to &1000
	STA VAL_1000,X			;(NMI routine D00-D93)
	DEX 
	BPL execcmd2_os7f_loop1

	JSR OS7F_SPECIAL_READ		;Only call to sub.
	LDX #&33			;Restore Mem

.execcmd2_os7f_loop2
	LDA VAL_1000,X			;Copy from &1000 to &D60-D93
	STA &0D60,X
	DEX 
	BPL execcmd2_os7f_loop2

	LDA NMI_FDCresult
	RTS
}

.OS7F_SPECIAL_READ
{
	LDA #&00			;Y=9
	STA &B4
	LDA (&B0),Y
	AND #&E0			;Sector size B4 B3
	BNE Label_8DD2			;000 128     01 80

	LDA #&10			;001 256     01 00

.Label_8DD2
	ASL A				;010 512     02 00
	ROL &B4				;011 1024    03 00**
	ASL A				;100 2048    04 00**
	ROL &B4				;101 4096    05 00**
	ASL A				;110 8192    06 00**
	ROL &B4				;111 16384   07 00**
	STA &B3				;Size=?&B4*&100-?&B3
	TAX 
	BEQ Label_8DE2

	INC &B4

.Label_8DE2
	JSR SetupNMI2_ReadOnly		;Special NMI READ routine
	LDA #&14
	STA &B7

.loop_8DE9
	LDA #&E0			;Read track
	STA NMI_FDCresult
	STA FDC_STATUS_COMMAND

.Label_8DF0
	LDA NMI_FDCresult		;Set by interrupt routine!
	BMI Label_8DF0			;Wait for result
	BNE Label_8E0D_RTS		;If error?

	LDA NMI_SecCounter		;Sectors to read
	BEQ Label_8E03

	DEC &B7
	BNE loop_8DE9			;Try again!

	LDA #&10
	STA NMI_FDCresult		;"Drive not ready"
	RTS 

.Label_8E03
	LDA &B6				;Data Mark/Deleted Data Mark
	EOR #&FB
	BEQ Label_8E0D_RTS		;If Data Mark

	LDA #&20			;"Deleted data found"
	STA NMI_FDCresult

.Label_8E0D_RTS
	RTS
}

.FDC_1770_Exec_ParamBlk_Cmd1
	LDY #&06			;Get command from parameter block
	LDA (&B0),Y			;A=cmd

.FDC_1770_ExecCommandA
{
	LDY #&FF

.execcmd1_loop1
	INY 				;Find command in table
	CMP fdccommands_table,Y
	BNE execcmd1_loop1

	PHA 
	LDA fdscommands_statusmasks,Y	;Status reg mask
	STA &0D05
	ROR NMI_FDCresult		;C=1; Set bit 7
	PLA 
	BPL execcmd1_TypeI_A_cmd	;If Type I command

	BIT NMI_Flags
	BVC execcmd1_precomp		;If bit 6 clear (not writing)

	LDY Track			;(i.e. if not command A0 or F0)
	CPY #&14
	BCC execcmd1_precomp		;If track<20

	ORA #&02			;Disable Write Precomp. (P=1)

.execcmd1_precomp
	STA NMI_FDCcommand
	LDY #&01
	CMP #&C0
	BEQ execcmd1_exec_A_fdccmd	;If Read Address

	ORA #&04			;Add 30ms settling delay (E=1)
	BCS execcmd1_exec_A_fdccmd		;If command>=&C0 (i.e. E0/F0)

	LDY NMI_SecCounter
	CMP #&85			;0101 i.e. was 81
	BEQ execcmd1_rdsec

	CMP #&87			;0111 i.e. was 83
	BNE execcmd1_exec_A_fdccmd

	LDA #&48			;Ignore data from FDC
	STA &0D09			;"D08 BEQ NMI1_8_read"

.execcmd1_rdsec
	LDA #&80			;Command = Read Sector
	STA NMI_FDCcommand
	LDA #&84			;Read sector (disable spin up)

.execcmd1_exec_A_fdccmd
	STY NMI_SecCounter
	STA FDC_STATUS_COMMAND
	CMP #&F0
	BCC execcmd1_waitloop		;If not formatting

	JSR FDC_1770_Wait_Busy1
	AND #&5C			;0101 1100
	STA NMI_FDCresult		;status
	RTS

.execcmd1_waitloop
	LDA NMI_FDCresult		;Wait for result
	BMI execcmd1_waitloop

	CMP #&20
	BNE execcmd1_exit		;If normal data found/motor spun

	JSR FDC_1770_Wait_Busy2

.execcmd1_exit
	LDA NMI_FDCresult		;A=result
	RTS

.execcmd1_TypeI_A_cmd
	LDY #&01			;Type I commands
	STY NMI_SecCounter
	ORA NMI_Timings
if sys=226
	STA NMI_FDCcommand
endif
	STA FDC_STATUS_COMMAND
	BIT &B2
	BMI execcmd1_waitloop		;If exec. osword 7f

	CMP #&20
	BCS execcmd1_waitloop		;If motor on or spin up completed

.execcmd1_typeI_waitloop
	LDA NMI_FDCresult		;Wait for result
	BPL execcmd1_typeI_exit

	LDA &FF
	BPL execcmd1_typeI_waitloop	;If not escape

	LDA #&40			;Escape presset so clean up
	STA NMIRoutine			;"RTI"
	LDA #&00
	STA FDC_DRIVECONTROL
	LDA &FF				;Bad result!
	STA LoadedCatDrive
	STA NMI_FDCresult

.execcmd1_typeI_exit
	RTS
}

.FDC_1770_Wait_Busy1
	LDA FDC_STATUS_COMMAND		;Command completed?
	ROR A
	BCC FDC_1770_Wait_Busy1		;If Busy bit clear

.FDC_1770_Wait_Busy2
	LDA FDC_STATUS_COMMAND
	ROR A
	BCS FDC_1770_Wait_Busy2		;If Busy bit set
	LDA FDC_STATUS_COMMAND
	RTS

.FDC_1770_ReadTrackAddress
{
	LDA #&48			;J=48->NMI1_8_read=ignore
	STA &0D4C			;data from FDC
	LDX &0D09			;X=K

.rta_loop
	SBC #&01			;IDLE?
	BNE rta_loop			;?
	STX &0D09			;K=X
	LDA #&04			;Ignore CRC
	STA NMI_ByteCounter
	JSR FDC_1770_Exec_ParamBlk_Cmd1
	BNE rta_exit			;If error

	DEC &B3				;Param 3 = Number of ID fields
	BNE rta_loop

.rta_exit
	RTS
}

.FDC_1770_StepIn
{
	JSR stepin3_execstepincmd	;Step In checking for bad tracks
	BNE stepin2_exit		;If error exit

	LDA CurrentDrv
	AND #&01
	ASL A
	TAY 				;Y=drive*2
	LDA Track
	BIT VAL_108A
	BPL stepin1_not40trkmode	;If not 40 track mode

	LSR A				;trk=trk*2

.stepin1_not40trkmode
	CMP BAD_TRACKS,Y		;Compare with bad tracks
	BEQ FDC_1770_StepIn		;If bad track step again

	CMP BAD_TRACKS+1,Y
	BEQ FDC_1770_StepIn		;If bad track step again

	LDA #&00			;A=0=ok

.stepin2_exit
	RTS 

.stepin3_execstepincmd
	BIT VAL_108A			;Only called from 8ECC
	BPL stepin4_not40trkmode	;If not 40 track mode

	LDA #&40			;Step-in u=0
	JSR stepin5_execcmdA
	BNE stepin2_exit		;If error

.stepin4_not40trkmode
	LDA #&50			;Step-in u=1

.stepin5_execcmdA
	INC Track
	JMP FDC_1770_ExecCommandA	;If u=1 then inc. track reg.
}

.FDC_1770_Seek_ParamBlk_Track
{
	LDA CurrentDrv			;Track in Parameter Block
	AND #&01			;Bit 0 = drive (Bit 1 = side)
	ASL A
	TAX 				;X=0 or 2
	LDY #&07
	LDA (&B0),Y			;A=track
	JSR spbtrk_SkipBadTracks	;(Only caller of this sub!)
	BIT VAL_108A
	BPL spbtrk_not40trkmode		;If not 40 track mode

	ASL A				;Double step!

.spbtrk_not40trkmode
	STA Track
	TAY 
	BEQ spbtrk_trk0			;If track 0 -> cmd 0

.spbtrk_loop
	STA FDC_DATA			;Data=desired track for seek
	CMP FDC_DATA
	BNE spbtrk_loop

	LDA #&10			;Seek track

.spbtrk_trk0
}
	JSR FDC_1770_ExecCommandA
	BNE skipbtrk2			;If error! ?

	LDY #&07			;If ok set FDC_TRACK
	LDA (&B0),Y			;A=track

.FDC_1770_SetTrack_A_track
	STA FDC_TRACK
	CMP FDC_TRACK
	BNE FDC_1770_SetTrack_A_track

	RTS 

.spbtrk_SkipBadTracks
	JSR skipbtrk1			;X=0 or 2 (only called from 8F09)
	INX 

.skipbtrk1
	CMP BAD_TRACKS,X		;X=1 to 3
	BCC skipbtrk2			;If A<M

	ADC #&00			;track+=1

.skipbtrk2
	RTS 				;Exit: A=track

