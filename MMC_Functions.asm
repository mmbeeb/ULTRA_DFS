	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2016                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : MMC_Functions.asm                                       \
	\-------------------------------------------------------------------\


	\ *********** MMC ERROR CODE ***********

	\\ Report MMC error
	\\ A=MMC response

.MMC_ReportErrS
{
	errno%=&B0
	errptr%=&B8

	LDY #&FF
	STY CurrentCat			; make catalogue invalid

	STA errno%

	JSR LEDS_reset

	PLA
	STA errptr%
	PLA
	STA errptr%+1

	LDY #0
	STY MMC_STATE
	STY &100

.loop	INY
	BEQ cont

	LDA (errptr%),Y
	STA &100,Y
	BNE loop

.cont	LDA errno%
	JSR PrintHex100			; print MMC response code

	LDA #'/'			; print MMC sector number
	STA &100,Y
	INY

	LDA par%
	JSR PrintHex100
	LDA par%+1
	JSR PrintHex100
	LDA par%+2
	JSR PrintHex100

.j100	LDA #0
	STA &100,Y
	JMP &100
}


	\*/ VID (Very Import Data) routines.

	\\ If these bytes get corrupted and we don't know about it,
	\\ it could lead to data on the MMC/SD card also becoming corrupted,
	\\ e.g. the wrong sector could be written to.
	\\ For this reason it is protected by a CRC.

	\ Reset the VID.
.VID_do_reset
{
	LDY #VID_SIZE-1
	LDA #0

.loop	STA VID,Y
	DEY
	BPL loop

	INC VID_CRC			;CRC7 = 1
	RTS
}

	\ Calculate and test VID CRC (CRC7).
	\ On exit: A=CRC7, X=0, Y=FF, Z=CRC correct.
.VID_calc_crc
{
	LDY #VID_SIZE-2
	LDA #0

.loop1	EOR VID,Y
	ASL A
	LDX #7

.loop2	BCC b7z1

	EOR #&12

.b7z1	ASL A
	DEX
	BNE loop2
	BCC b7z2

	EOR #&12

.b7z2	DEY
	BPL loop1

	ORA #&01
	CMP VID_CRC
	RTS
}

	\ Check the VID CRC, and if wrong report error.
	\ On exit: If no error, all registers preserved.
.VID_check_report
{
	JSR rememberAXY
	JSR VID_calc_crc
	BNE errBadCRC

	RTS

.errBadCRC
	JSR errBAD
	EQUB &FF
	EQUS "CRC",0
}

	\ Reset the VID CRC (i.e. after VID written to).
	\ On exit: All registers preserved.
.VID_reset_crc
	JSR rememberAXY
	JSR VID_calc_crc
	STA VID_CRC
	RTS


	\*/ Keyboard LEDs.

	\ Illuminate Caps Lock & Shift Lock LEDs to signify MMC busy.
	\ (No OS call to do this without changing keyboard state.)
.LEDS_set
	LDX #&6
	STX SYSVIA
	INX
	STX SYSVIA
	RTS

	\ Reset LEDs to reflect keyboard state.
	\ On exit: All registers preserved.
.LEDS_reset
	JSR rememberAXY
	LDA #&76
	JMP OSBYTE


	\ ** Convert 9 bit binary in word &B8 to
	\ ** 3 digit BCD in word &B5 (decno%)
decno%=&B5

	\Used by GetDisk
.DecNo_BIN2BCD
{
	LDX &B8
	LDY #0
	STY decno%+1

.b2b_loop
	TXA
	CMP #10
	BCC b2b_exloop

	SBC #10
	TAX
	SED
	CLC
	TYA
	ADC #&10
	TAY
	CLD
	BCC b2b_loop

	INC decno%+1
	BCS b2b_loop

.b2b_exloop
	SED
	STY decno%
	ADC decno%
	TAY
	BCC b2b_noinc

	INC decno%+1
	CLC

.b2b_noinc
	LDX &B9 			; >&FF ?
	BEQ b2b_noadd

	ADC #&56
	TAY
	LDA decno%+1
	ADC #&02
	STA decno%+1

.b2b_noadd
	CLD
	STY decno%
	RTS
}

	\\ **** Read decimal number at TxtPtr+Y ****
	\\ on exit;
	\\ if valid (0 - 510);
	\\ C=0, AX=number, &
	\\ Y points to next chr
	\\ if not valid;
	\\ C=1, AX=0, &
	\\ Y=entry value
	\\ Exit: Uses memory &B0 + &B1

rn%=&B0

.Param_ReadNum
{
	TYA
	PHA				;\ 1
	LDA #0
	STA rn%
	STA rn%+1

	JSR GSINIT_A
	BEQ rnnotval			; If null string

	CMP #&22
	BEQ rnnotval

	JSR GSREAD
	BCS rnnotval			; Should never happen!

.rnloop
	SEC
	SBC #48
	BMI rnnotval

	CMP #10
	BCS rnnotval

	\\ N=N*2+N*8+A
	PHA				;\ 2
	LDA rn%
	ASL A
	PHA				;\ 3
	ROL rn%+1
	LDX rn%+1
	ASL A
	ROL rn%+1
	ASL A
	ROL rn%+1
	STA rn%
	PLA				;\ 3
	ADC rn%
	STA rn%
	TXA
	ADC rn%+1
	TAX
	PLA				;\ 2
	ADC rn%
	STA rn%
	TXA
	ADC #0
	STA rn%+1
	CMP #2
	BCS rnnotval

	JSR GSREAD
	BCC rnloop

	\\ <>511?
.rnexit
	LDX rn%
	LDA rn%+1
	BEQ rnok

	INX
	BEQ rnnotval

	DEX
.rnok
	PLA 				;\ 1 - ignore Y
	LDA rn%+1
	CLC
	RTS

	\ Not a valid number, restore Y and set C
.rnnotval
	PLA				;\ 1
	TAY 				; restore Y
	LDA #0
	TAX
	SEC
	RTS
}

.jmpSYNTAX
	JMP errSYNTAX

.errDISKNOTFOUND
	JSR errDISK
	EQUB 214
	EQUS "not found",0



	\\ Read parameters : drive optional
	\\ (<drive>) <dno>/<dsp>
	\\ Exit: CurrentDrv=drive, Word &B8=disk no.

.Param_DriveAndDisk
{
	JSR Param_SyntaxErrorIfNull

	CMP #&22
	BNE label1

	DEY

.label1	STY &B4				; Save Y
	JSR GSREAD_A

	CMP #':'			; ASC(":")
	BNE label2

	JSR Param_DriveNo_BadDrive
	BCC Param_Disk			; always

.label2	LDY &B4				; Restore Y
	JSR Set_CurDrv_ToDefault

	\ Read 1st number
	JSR Param_ReadNum		; rn% @ B0
	BCS gddfind			; if not valid number

	JSR GSINIT_A
	BEQ gdnodrv			; if rest of line blank

	CMP #&22
	BNE label3

	DEY

.label3	LDA rn%+1
	BEQ label5			; AX<256

.label4	JMP errBADDRIVE

.label5	LDA rn%
	CMP #4
	BCS label4

	JSR SetCurrentDrive_Adrive
}


	\ Read (2nd) number?
	\ If it's not a valid number:
	\ assume it's a disk name
	\ <dno>/<dsp>
	\ Exit: Word &B8 = disk no.
.Param_Disk
	JSR Param_ReadNum		; rn% @ B0
	BCS gddfind			; if not valid number

	JSR GSINIT_A
	BNE jmpSYNTAX2			; if rest of line not blank

.gdnodrv
	LDA rn%+1
	STA &B9
	LDA rn%
	STA &B8

.gddfound
	RTS

.jmpSYNTAX2
	JMP errSYNTAX


	\ The parameter is not valid number;
	\ so it must be a disk name?!
gdptr%=&B0
gdsec%=&B2
gddiskno%=&B8
gdopt%=&B7

.gddfind
{
	JSR DMatchInit
	LDA #0
	STA gdopt%			; don't return unformatted disks
	JSR GetDiskFirstAll
	LDA dmLen%
	BEQ jmpSYNTAX2

	LDA dmAmbig%
	BNE jmpSYNTAX2

.gddlp
	LDA gddiskno%+1
	BMI errDISKNOTFOUND2

	JSR DMatch
	BCC gddfound

	JSR GetDiskNext
	JMP gddlp
}

.errDISKNOTFOUND2
	jmp errDISKNOTFOUND


	\\ **** Check drive not write protected ****
.CheckWriteProtect
	LDX CurrentDrv
	LDA DRIVE_INDEX4,X		; Bit 5 set = protected
	AND #&20
	BNE errReadOnly

	RTS

	\\ *** Set word &B8 to disk in current drive ***
	\\ Check: C=0 drive loaded with formatted disk
	\\        C=1 drive loaded with unformatted disk
.SetCurrentDiskC
	JSR chkdrv1

.SetCurrentDiskX
	LDA DRIVE_INDEX0,X
	STA &B8
	LDA DRIVE_INDEX4,X
	AND #&0F
	STA &B9
	RTS


	\\ * Check drive loaded with formatted disk *
.CheckCurDrvFormatted
	CLC

.chkdrv1
{
	LDX CurrentDrv
	LDA DRIVE_INDEX4,X
	ROL A
	BPL errNoDisk			; Bit 7 clear = no disk

	ROR A	
	AND #&10
	BCS chkdrv2

	BNE errNotFormatted		; Bit 3 set = unformatted

	RTS

.chkdrv2
	BEQ errFormatted		; Bit 3 clear = formatted

	RTS
}					; exit: X=drive no

.errReadOnly
	JSR errDISK
	EQUB &C9
	EQUS "read only",0

.errNoDisk
	JSR ReportError
	EQUB &C7
	EQUS "No disc",0

.errNotFormatted
	JSR errDISK
	EQUB &C7
	EQUS "not formatted",0

.errFormatted
	JSR errDISK
	EQUB &C7
	EQUS "already formatted",0


	\\ **** Calc first MMC sector of disk ****
	\\ sec% = MMC_SECTOR + 32 + drvidx * 800
	\\ Call after MMC_BEGIN

	\\ Current drive
.DiskStart_CurDrv
	JSR CheckCurDrvFormatted	; On exit X=drive

.DiskStart_DrvX
	LDA DRIVE_INDEX4,X
	ROR A				; C = bit 0
	LDA DRIVE_INDEX0,X

	\\ A=drvidx, C=bit 8
	\\ S=I*512+I*256+I*32

	PHP 				;\ 1
	TAX
	LDA #0
	STA sec%
	ROL A
	PHA 				;\ 2
	STA sec%+2
	TXA
	ASL A
	ROL sec%+2			; C=0
	STA sec%+1
	TXA
	ADC sec%+1
	STA sec%+1
	PLA				;\ 2
	ADC #0				; C=0
	ADC sec%+2
	STA sec%+2
	ROR sec%
	TXA
	PLP				;\ 1
	ROR A
	ROR sec%
	LSR A
	ROR sec%
	LSR A
	ROR sec%
	ADC sec%+1
	STA sec%+1
	LDA sec%+2
	ADC #0
	STA sec%+2

	\\ add offset + 32
	SEC
	LDA sec%
	ORA #&1F			; 32
	ADC MMC_SECTOR
	STA sec%
	LDA sec%+1
	ADC MMC_SECTOR+1
	STA sec%+1
	LDA sec%+2
	ADC MMC_SECTOR+2
	STA sec%+2
	RTS


	\\ **** Initialise VARS for MMC R/W ****
	\\ Call only after MMC_BEGIN
	\\ Note: Values in BC-C5 copied to 10B0-10B9 (MMC_WSP)
	\\ Also checks disk loaded/formatted
.CalcRWVars
{
	JSR DiskStart_CurDrv

	\\ add start sector on disk
	CLC
	LDA MMC_WSP+7	;MA+&1097
	ADC sec%
	STA sec%
	LDA MMC_WSP+6	;MA+&1096
	AND #3
	PHA
	ADC sec%+1
	STA sec%+1
	BCC cvskip

	INC sec%+2

	\\ calc sector count
.cvskip
	LDA MMC_WSP+5	;MA+&1095
	STA seccount%
	LDA MMC_WSP+6	;MA+&1096			; mixed byte
	LSR A
	LSR A
	LSR A
	LSR A
	AND #3
	BNE errBlockSize

	LDA MMC_WSP+4	;MA+&1094
	STA byteslastsec%
	BEQ cvskip2

	INC seccount%
	BEQ errBlockSize

	\\ check for overflow
.cvskip2
	CLC
	LDA MMC_WSP+7	;MA+&1097
	ADC seccount%
	TAX
	PLA
	ADC #0
	CMP #3
	BCC cvnoof
	BNE errOverflow

	CPX #&21
	BCS errOverflow

.cvnoof
	RTS

.errBlockSize
	JSR ReportError
	EQUB &FF
	EQUS "Block too big",0

.errOverflow
	JSR errDISK
	EQUB &FF
	EQUS "overflow",0
}


	\\ Return state of active drive.
.MMC_ActiveDrv_State
	LDA ActiveDrv

	\\ Return the state of drive.
	\\ Entry: A = drive number
	\\ Exit : A & X undefined, Y preserved, C=state (1=virtual, 0=real).
.MMC_Drive_State
	AND #3
	TAX
	LDA DRIVE_INDEX4,X
IF sys<>224				; Master: Assume FDC always present.
	LDX PagedRomSelector_RAMCopy
	ORA PagedROM_PrivWorkspaces,X 	; If FDC absent all drives a virtual!
ENDIF
	ROL A				; C = bit 7
	RTS


	\\ Route flow depending on state of active drive.
	\\ JSR A -> JSR B -> JSR C - > JSR MMC_Route_ActiveDrv
	\\ If the active drive is virtual return to C else return to B,
	\\ C and B return to A (i.e. C does not return to B).
	\\ A, X & Y preserved.
.MMC_Route_ActiveDrv
{
	PHA
	TXA
	PHA

	JSR MMC_ActiveDrv_State

	TSX
	BCC real

	LDA &104,X
	STA &106,X
	LDA &103,X
	STA &105,X

.real	LDA &102,X
	STA &104,X

	PLA
	TAX
	PLA
	PLA
	PLA
	RTS
}

.MMC_LoadMemBlock
	JSR MMC_Route_ActiveDrv
	JSR MMC_BEGIN1
	JSR CalcRWVars

.readblock
	JSR MMC_ReadBlock

.rwblkexit
{
	LDA TubeNoTransferIf0
	BEQ rwblknottube

	JSR TUBE_RELEASE_NoCheck

.rwblknottube
	JSR MMC_END
	LDA #1
	RTS
}

	\\ **** Save block of memory ****
.MMC_SaveMemBlock
	JSR MMC_Route_ActiveDrv
	JSR MMC_BEGIN1
	JSR CalcRWVars
	JSR CheckWriteProtect

.writeblock
	JSR MMC_WriteBlock
	JMP rwblkexit

IF sys=120
.MMC_SaveCatToDisk
	LDY #&A0
	BNE MMC_RW_Catalogue

.MMC_LoadCurDrvCat
	LDY #&80
ENDIF


	\\ Read/Write Catalogue
	\\ Entry: Y=Operation (&A0=Write)
.MMC_RW_Catalogue
{
	JSR MMC_Route_ActiveDrv
	CPY #&A0
	PHP

	JSR MMC_BEGIN1
	JSR DiskStart_CurDrv

	PLP
	BEQ savecat

	JSR MMC_ReadCatalogue

.setcat	LDA ActiveDrv
	STA CurrentCat
	JMP MMC_END

.savecat
	JSR CheckWriteProtect
	JSR MMC_WriteCatalogue
	JMP setcat
}


	\\ **** Calc disk table sec & offset ****
	\\ Entry: D = Disk no (B8)
	\\ Exit: (B0) = &E00 + (D + 1) x 16
	\\     : A=Table Sector Code
	\\ Note; D = 511 not valid
.GetIndex
{
	LDA &B9
	ROR A
	LDY &B8
	INY
	TYA
	BNE gix1

	SEC

.gix1	ROL A
	ROL A
	ROL A
	ROL A
	ROL A
	PHA				;\ 1
	AND #&1F
	TAY
	PLA				;\ 1
	ROR A
	AND #&F0

	STA &B0
	TYA
	AND #&01
	ORA #MP+&0E
	STA &B1

	TYA				; A = table sector code
	AND #&FE
	ORA #&80
	RTS				; X unchanged
}


	\\ Return status of disk in current drive
.GetDriveStatus
	CLC				; check loaded with formatted disk

.GetDriveStatusC
	JSR SetCurrentDiskC


	\\ &B8 = disk no
	\\ On exit; A=disk status byte
	\\ from Disk Table
	\\ &B0 points to location in table (cat)
	\\ Z & N set on value of A
	\\ Disk Table sector
	\\ for disk in cat area
.GetDiskStatus
{
	JSR GetIndex
	JSR CheckDiskTable
	LDY #15
	LDA (&B0),Y
	CMP #&FF
	BEQ ErrNotValid

	TAX				; reset flags
	RTS
	\\ Type: 00=RO, 0F=RW, F0=Unformatted, FF=Invalid
	\\ Z=1=RO, N=1=Unformatted else RW

.ErrNotValid
	JSR errDISK
	EQUB &C7
	EQUS "number not valid",0
}


	\\ **** If disk in any drive, unload it ****
	\\ Word &B8=diskno (X,Y preserved)
	\\ Doesn't check/update CRC7
.UnloadDisk
{
	TXA
	PHA
	LDX #3

.loop	LDA DRIVE_INDEX4,X
	BPL skip			; If real drive

	AND #&0F
	CMP &B9
	BNE skip

	LDA DRIVE_INDEX0,X
	CMP &B8
	BNE skip

	LDA #&80			; V... Virtual but no disk loaded.
	STA DRIVE_INDEX4,X

.skip	DEX
	BPL loop

	PLA				; Restore X
	TAX
	RTS
}


	\\ **** Load current drive with disk ****
	\\ Word &B8 = Disc number
.LoadDrive
	LDA ActiveDrv

.LoadDriveA
{
	PHA

	LDA #&E0			; VLP.
	STA &B7

	JSR GetDiskStatus
	BEQ ldiskro			; 00 = read only
	BPL ldiskrw			; 0F = read/write

	\CMP #&F0			; F0 = unformatted
	\BNE [.notvaliderr]		; Disk number not valid

	LDA #&D0			; VL.U
	BNE ldisknf			; not formatted

.ldiskrw
	LDA #&C0			; VL..

.ldisknf
	STA &B7

.ldiskro
	JSR VID_check_report

	\ Make sure disk is not in another drive
	JSR UnloadDisk

	PLA
	TAX

	;;LDX CurrentDrv
	LDA &B8
	STA DRIVE_INDEX0,X
	LDA &B9
	ORA &B7				; Loaded
	STA DRIVE_INDEX4,X
	JMP VID_reset_crc
}

	\\ **** Calculate disk table sector ****
	\\ A=sector code (sector + &80)
.DiskTableSec
	AND #&7E
	CLC
	ADC MMC_SECTOR
	STA sec%
	LDA MMC_SECTOR+1
	ADC #0
	STA sec%+1
	LDA MMC_SECTOR+2
	ADC #0
	STA sec%+2

.ldtloaded
	RTS

	\\ A=sector code (sector or &80)
.CheckDiskTable
	CMP CurrentCat
	BEQ ldtloaded

	\\ A=sector code

	STA CurrentCat
	JSR DiskTableSec
	JMP MMC_ReadCatalogue

.SaveDiskTable
	LDA CurrentCat
	JSR DiskTableSec
	JMP MMC_WriteCatalogue


	\\ GetDisk, returns name of disks
	\\ in DiskTable (used by *DCAT)
	\\ for disks with no's in range
	\\ On exit C clear if disk found
	\\ and A contains disk status

	\\ Set up and get first disk
	\\ Word &B8=first disk no
	\\ If ?&B7=0, skip unformatted disks

.GetDiskFirst
	JSR DecNo_BIN2BCD
	JSR GetIndex
	STA gdsec%
	JSR CheckDiskTable
	JMP gdfirst

	\\ Return ALL disks
.GetDiskFirstAll
	LDA #0
	STA decno%
	STA decno%+1
	STA gddiskno%
	STA gddiskno%+1
	LDA #&10
	STA gdptr%
	LDA #MP+&0E
	STA gdptr%+1
	LDA #&80
	STA gdsec%
	JSR CheckDiskTable
	JMP gdfirst

.gdnextloop
	CMP #&FF
	BEQ gdfin
	BIT gdopt%			; Return unformatted disks?
	BMI gdfrmt			; If yes

	\\ Get next disk
.GetDiskNext
	CLC
	LDA gdptr%
	ADC #16
	STA gdptr%
	BNE gdx1

	LDA gdptr%+1
	EOR #1
	STA gdptr%+1
	ROR A
	BCS gdx1

	LDA gdsec%
	ADC #2
	CMP #&A0			; (&80 OR 32)
	BEQ gdfin

	STA gdsec%
	JSR CheckDiskTable

.gdx1
	INC gddiskno%
	BNE gdx50

	INC gddiskno%+1

.gdx50
	\\ inc decno%
	SED
	CLC
	LDA decno%
	ADC #1
	STA decno%
	BCC gddec

	INC decno%+1

.gddec
	CLD

.gdfirst
	LDY #&F
	LDA (gdptr%),Y
	BMI gdnextloop			; If invalid / unformatted

	\ Disk found
.gdfrmt
	CLC
	RTS

	\ No more disks
.gdfin
	LDA #&FF
	STA gddiskno%+1
	SEC
	RTS



	\\ *** Set up the string to be compared ***
	\\ The match string is at (txtptr%)+Y
	\\ Max length=12 chrs (but allow 0 terminator)
dmStr%=MA+&1000		; location of string
dmLen%=MA+&100D		; length of string
dmAmbig%=MA+&100E	; string terminated with *

.DMatchInit
{
	LDX #0
	STX dmAmbig%

	CLC
	JSR GSINIT
	BEQ dmiExit			; null string

.dmiLoop
	JSR GSREAD
	BCS dmiExit
	CMP #'*'			; ASC("*")
	BEQ dmiStar			; if ="*"

	\ UCASE
	CMP #&61			; ASC("a")
	BCC dmiUcase			; if <"a"

	CMP #&7B			;ASC("z")+1
	BCS dmiUcase			; if >"z"

	EOR #&20

.dmiUcase
	STA dmStr%,X

	INX
	CPX #12
	BNE dmiLoop

	\ Make sure at end of string
.dmiEnd
	JSR GSREAD
	BCC ErrBadString		; If not end of string

.dmiExit
	CMP #&0D
	BNE dmiSyntax			; Syntax?

	LDA #0
	STA dmStr%,X
	STX dmLen%
	RTS

	\ Wildcard found, must be end of string
.dmiStar
	STA dmAmbig%
	BEQ dmiEnd			; always

.ErrBadString
	JSR ReportError
	EQUB &FF
	EQUS "Bad string",0

.dmiSyntax
	JMP errSYNTAX
}

	\\ *** Perform string match ****
	\\ String at (gdptr%)+Y
	\\ C=0 if matched
.DMatch
{
	LDY #0
	LDX dmLen%
	BEQ dmatend

.dmatlp
	LDA (gdptr%),Y
	BEQ dmatnomatch

	CMP #&61			; ASC("a")
	BCC dmnotlc

	CMP #&7B			; ASC("z")+1
	BCS dmnotlc

	EOR #&20

.dmnotlc
	CMP dmStr%,Y
	BNE dmatnomatch

	INY
	DEX
	BNE dmatlp

.dmatend
	LDA (gdptr%),Y
	BEQ dmmatyes

	LDA dmLen%
	CMP #12
	BEQ dmmatyes

	LDA dmAmbig%
	BEQ dmatnomatch

.dmmatyes
	CLC
	RTS

.dmatnomatch
	SEC
	RTS
}


	\ Update title in disk table for disk in current drive
	\ The catalogue of the disk must be loaded.
	\ (Called after *TITLE and *BACKUP)
.MMC_UpdateDiskTableTitle
{
	titlestr%=MA+&1000		;16 bytes used.

	JSR MMC_ActiveDrv_State
	BCC exit			;If real drive.

	\ Copy title from catalogue

	LDX #7

.loop1	LDA MA+&0E00,X
	STA titlestr%,X
	LDA MA+&0F00,X
	STA titlestr%+8,X
	DEX
	BPL loop1

	\ Load drive table

	JSR GetDriveStatus

	LDY #11

.loop2	LDA titlestr%,Y
	STA (&B0),Y
	DEY
	BPL loop2

	JMP SaveDiskTable

.exit 	RTS
}


\\//\\// End of file \\//\\//
