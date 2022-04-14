	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2015                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : mmc_drives.asm                                          \
	\-------------------------------------------------------------------\


	\\ **** Check drive not write protected ****
.CheckWriteProtect
	LDX CurrentDrv
	LDA VID_DRIVE_INDEX4,X		;Bit 6 set = protected
	ASL A
	BMI errReadOnly

	RTS

	\\ *** Set word &B8 to disk in current drive ***
	\\ Check: C=0 drive loaded with formatted disk
	\\        C=1 drive loaded with unformatted disk
.SetCurrentDiskC
	JSR chkdrv1
	LDA VID_DRIVE_INDEX0,X
	STA &B8
	LDA VID_DRIVE_INDEX4,X
	AND #1
	STA &B9
	RTS

	\\ * Check drive loaded with unformatted disk *
.CheckCurDrvUnformatted
	SEC
	BCS chkdrv1

	\\ * Check drive loaded with formatted disk *
.CheckCurDrvFormatted
	CLC

.chkdrv1
{
	LDX CurrentDrv
	LDA VID_DRIVE_INDEX4,X
	BPL errNoDisk			; Bit 7 clear = no disk

	AND #&08
	BCS chkdrv2
	BNE errNotFormatted		; Bit 3 set = unformatted

	RTS

.chkdrv2
	BEQ errFormatted		; Bit 3 clear = formatted

	RTS
}					; exit: X=drive no

.errReadOnly
	JSR errDISK
	EQUB &C9, "read only", 0

.errNoDisk
	;JSR ReportError
	EQUB &C7, "No disc", 0

.errNotFormatted
	JSR errDISK
	EQUB &C7, "not formatted", 0

.errFormatted
	JSR errDISK
	EQUB &C7, "already formatted", 0


	\\ **** Calc first MMC sector of disk ****
	\\ sec% = MMC_SECTOR + 32 + drvidx * 800
	\\ Call after MMC_BEGIN

	\\ Current drive
.DiskStart
	JSR CheckCurDrvFormatted	; X=drive

.DiskStartX
	LDA VID_DRIVE_INDEX4,X
	ROR A				; C = bit 0
	LDA VID_DRIVE_INDEX0,X

	\\ A=drvidx, C=bit 8
	\\ S=I*512+I*256+I*32
.DiskStartA
{
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
	ADC VID_MMC_SECTOR
	STA sec%
	LDA sec%+1
	ADC VID_MMC_SECTOR+1
	STA sec%+1
	LDA sec%+2
	ADC VID_MMC_SECTOR+2
	STA sec%+2
	RTS
}


	\\ **** Initialise VARS for MMC R/W ****
	\\ Call only after MMC_BEGIN
	\\ Note: Values in BC-C5 copied to 1090-1099
	\\ Also checks disk loaded/formatted
.CalcRWVars
{
	JSR DiskStart

	\\ add start sector on disk
	CLC
	LDA MA+&1097
	ADC sec%
	STA sec%
	LDA MA+&1096
	AND #3
	PHA
	ADC sec%+1
	STA sec%+1
	BCC skip1

	INC sec%+2

	\\ calc sector count
.skip1	LDA MA+&1095
	STA seccount%
	LDA MA+&1096			;mixed byte
	LSR A
	LSR A
	LSR A
	LSR A
	AND #3
	BNE errBlockSize

	LDA MA+&1094
	STA byteslastsec%
	BEQ skip2

	INC seccount%
	BEQ errBlockSize

	\\ check for overflow
.skip2
	CLC
	LDA MA+&1097
	ADC seccount%
	TAX
	PLA
	ADC #0
	CMP #3
	BCC noof
	BNE errOverflow

	CPX #&21
	BCS errOverflow

.noof	RTS

.errBlockSize
	;JSR ReportError
	EQUB &FF
	EQUS "Block too big",0

.errOverflow
	JSR errDISK
	EQUB &FF
	EQUS "overflow",0
}


\.LoadMemBlock
.mmc_load_mem_block
	JSR MMC_BEGIN1
	JSR CalcRWVars

.readblock
	JSR MMC_ReadBlock

.rwblkexit
{
	LDA TubeNoTransferIf0
	BEQ nottube

;;;	JSR TUBE_RELEASE_NoCheck where in 1.20

.nottube
	JSR MMC_END
	LDA #1
	RTS
}

	\\ **** Save block of memory ****
\.SaveMemBlock
.mmc_save_mem_block
	JSR MMC_BEGIN1
	JSR CalcRWVars
	JSR CheckWriteProtect

.writeblock
	JSR MMC_WriteBlock
	JMP rwblkexit


	\\ **** Check if loaded catalogue is that
	\\ of the current drive, if not load it ****
\.CheckCurDrvCat
\	LDA CurrentCat
\	CMP CurrentDrv
\	BNE LoadCurDrvCat
\	RTS 

	\\ **** Load catalogue of current drive ****
\.LoadCurDrvCat
.mmc_load_cat
	JSR MMC_BEGIN1
	JSR DiskStart
	JSR MMC_ReadCatalogue

.rwcatexit
	LDA CurrentDrv
	STA CurrentCat
	JMP MMC_END

	\\ **** Save catalogue of current drive ****
\.SaveCatToDisk
.mmc_save_cat
	LDA MA+&0F04			; Increment Cycle Number
	CLC 
	SED 
	ADC #&01
	STA MA+&0F04
	CLD 

	JSR MMC_BEGIN1
	JSR DiskStart
	JSR CheckWriteProtect
	JSR MMC_WriteCatalogue
	JMP rwcatexit



	;;; THIS WILL GO IN OS7F EMUL CODE
	\ **** Read / Write 'track' ****
	\ ?&C9 : -ve = write, +ve = read
	\ ?&B4 : track number
	\ (Used by CMD_VERIFY / CMD_FORM)
.RW_Track
{
	LDA &B4
	BNE rwtrk1
	LDX CurrentDrv
	JSR DiskStartX

.rwtrk1
	LDA #5
	STA &B6

.rwtrk2_loop
	BIT &C9
	BMI rwtrk3

	JSR MMC_ReadCatalogue		; verify
	JMP rwtrk4

.rwtrk3
	JSR MMC_WriteCatalogue		; format

.rwtrk4
	INC sec%
	INC sec%
	BNE rwtrk5

	INC sec%+1
	BNE rwtrk5

	INC sec%+2

.rwtrk5
	DEC &B6
	BNE rwtrk2_loop

	RTS
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
\.GetDiskStatus
.mmc_get_disk_status
{
	JSR mmc_disk_table_set_index
	JSR CheckDiskTable

	LDY #15
	LDA (&B0),Y
	CMP #&FF
	BEQ ErrNotValid

	TAX				;reset flags
	RTS

	\\ Type: 00=RO, 0F=RW, F0=Unformatted, FF=Invalid
	\\ Z=1=RO, N=1=Unformatted else RW

.ErrNotValid
	JSR errDISK
	EQUB &C7, "number not valid", 0
}

	\ Unload drive A (it reverts to a physical drive).
.mmc_unload_drive
	JSR VID_check_report
	LDX CurrentDrv
	TXA					;A < 4
	STA VID_DRIVE_INDEX4,X			;Clear high nybble.
	JMP VID_reset_crc


	\temp stuff:
;.mmc_load_drive
;	jsr VID_check_report
;	ldx CurrentDrv
;	lda &B8
;	sta VID_DRIVE_INDEX0,X
;	lda &B9
;	ora #&80
;	sta VID_DRIVE_INDEX4,X
;	jmp VID_reset_crc
;



	\\ **** Load current drive with disk ****
	\\ Word &B8 = Disc number
.mmc_load_drive
{
	LDA #&C0
	STA &B7

	JSR mmc_get_disk_status
	BEQ ro				;00 = read only
	BPL rw				;0F = read/write

	\CMP #&F0			;F0 = unformatted
	\BNE [.notvaliderr]		;Disk number not valid

	LDA #&C8
	BNE nf				;not formatted

.rw	LDA #&80

.nf	STA &B7

.ro	JSR VID_reset_crc

	\ Make sure disk is not in another drive.
	JSR mmc_unload_disk ;UnloadDisk

	LDX CurrentDrv
	LDA &B8
	STA VID_DRIVE_INDEX0,X
	LDA &B9
	ORA &B7				;Loaded
	STA VID_DRIVE_INDEX4,X
	JMP VID_reset_crc
}

	\\ **** If disk in any drive, unload it ****
	\\ Word &B8=diskno (X,Y preserved)
	\\ Doesn't check/update CRC7
	\\ Exit: X & Y preserved.
.mmc_unload_disk
{
	TXA
	PHA

	LDX #3

.loop	LDA VID_DRIVE_INDEX0,X
	CMP &B8
	BNE skip

	LDA VID_DRIVE_INDEX4,X
	AND #1
	CMP &B9
	BNE skip

	STA VID_DRIVE_INDEX4,X		;Reset bit 7

.skip	DEX
	BPL loop

	PLA				;Restore X
	TAX
	RTS
}


	\\ **** Calculate disk table sector ****
	\\ A=sector code (sector + &80)
.DiskTableSec
	AND #&7E
	CLC
	ADC VID_MMC_SECTOR
	STA sec%
	LDA VID_MMC_SECTOR+1
	ADC #0
	STA sec%+1
	LDA VID_MMC_SECTOR+2
	ADC #0
	STA sec%+2

.ldtloaded
	RTS

	\\ A=sector code (sector or &80)
.CheckDiskTable
	CMP CurrentCat
	BEQ ldtloaded

	\\ A=sector code
.LoadDiskTable
	STA CurrentCat
	JSR DiskTableSec
	JMP MMC_ReadCatalogue

.SaveDiskTable
	LDA CurrentCat
	JSR DiskTableSec
	JMP MMC_WriteCatalogue


	\\ **** Calc disk table sec & offset ****
	\\ Entry: D = Disk no (B8)
	\\ Exit: (B0) = &E00 + (D + 1) x 16
	\\     : A=Table Sector Code
	\\ Note; D = 511 not valid
\.GetIndex
.mmc_disk_table_set_index
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
	JSR mmc_disk_table_set_index
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



	\\ *DRECAT
	\\ Refresh disk table with disc titles

	\ load first sector of disk table
.CMD_DRECAT
{
	LDA #&80
	STA gdsec%
	JSR LoadDiskTable

	\ pointer to first entry
	LDA #&10
	STA gdptr%
	LDA #MP+&0E
	STA gdptr%+1

	\ set read16sec% to first disk
	LDA #0
	CLC
	JSR DiskStartA
	LDX #3
.drc_loop1
	LDA sec%,X
	STA read16sec%,X
	DEX
	BPL drc_loop1

	\ is disk valid?
.drc_loop2
	LDY #15
	LDA (gdptr%),Y
	CMP #&FF
	BEQ drc_label5			; If disc not valid

	\ read disc title
	JSR MMC_ReadDiscTitle

	\ read16sec% += 800
	CLC
	LDA read16sec%
	ADC #&20
	STA read16sec%
	LDA read16sec%+1
	ADC #&03
	STA read16sec%+1
	BCC drc_label3
	INC read16sec%+2

	\ copy title to table
.drc_label3
	LDY #&0B
.drc_loop4
	LDA read16str%,Y
	STA (gdptr%),Y
	DEY
	BPL drc_loop4

	\ gdptr% += 16
	CLC
	LDA gdptr%
	ADC #16
	STA gdptr%
	BNE drc_loop2
	LDA gdptr%+1
	EOR #1
	STA gdptr%+1
	ROR A
	BCS drc_loop2

	\ If gdptr% = 0
	JSR SaveDiskTable
	CLC
	LDA gdsec%
	ADC #2
	CMP #&A0			; (&80 OR 32)
	BEQ drc_label7			; if end of table
	STA gdsec%

	JSR CheckESCAPE

	JSR LoadDiskTable
	JMP drc_loop2

	\ Has this sector been modifed?
	\ ie is gdptr% <> 0
.drc_label5
	LDA gdptr%
	BNE drc_label6
	ROR gdptr%+1
	BCC drc_label7
.drc_label6
	JMP SaveDiskTable

.drc_label7
	RTS
}


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
;	JSR ReportError
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

