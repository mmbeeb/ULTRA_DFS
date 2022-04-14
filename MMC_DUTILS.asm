	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2016                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : MMC_DUTILS.asm                                          \
	\-------------------------------------------------------------------\


	\\ **** Print disk no & title ****
.PrintDCat
{
	BCS pdcnospc

	LDA #&20
	JSR PrintChrA

.pdcnospc
	LDX #&20
	JSR DecNo_Print

	LDA #&20
	JSR PrintChrA

	LDY #15
	LDA (gdptr%),Y
	BMI pdcnotform

	LDY #0
.pdcloop
	LDA (gdptr%),Y
	BEQ pdcspc

	JSR PrintChrA
	INY
	CPY #12
	BNE pdcloop

.pdcspc	LDA #&20

.pdcspclp
	JSR PrintChrA
	INY
	CPY #13
	BNE pdcspclp

	TAX
	LDY #15
	LDA (gdptr%),Y
	BNE pdcnoprot

	LDX #&50			; ASC("P")

.pdcnoprot
	TXA
	JMP PrintChrA

.pdcnotform
	LDY #13
	JSR prt_Yspaces
	LDA #&55
	JMP PrintChrA
}


	\ Print 4 dig decno% padded with chr X
.DecNo_Print
	LDY #4
	LDA decno%+1
	JSR PrintDec
	LDA decno%


.PrintDec
{
	PHA
	LSR A
	LSR A
	LSR A
	LSR A
	JSR pdec1
	PLA

.pdec1	AND #&F
	BEQ pdec2

	LDX #&30
	CLC
	ADC #&30
	JMP PrintChrA

.pdec2	DEY
	BNE pdec3

	LDX #&30

.pdec3	TXA
	JMP PrintChrA
}


	\\ *DABOUT -  PRINT INFO STRING
.CMD_DABOUT
	JSR PrintString
	EQUS "DUTILS by Martin Mather "

.vstr	EQUS "(2016)",13
	NOP
	RTS


	\\ *DBOOT <dno>/<dsp>
.CMD_DBOOT
	JSR Param_SyntaxErrorIfNull
	LDA #0
	STA CurrentDrv
	JSR Param_Disk			; CurrentDrv=drive / B8=disk no.
	JSR LoadDrive
	LDA #&00
	JMP initDFS


	\\ *DIN (<drive>)
	\\ Load drive
.CMD_DIN
	JSR Param_DriveAndDisk
	JMP LoadDrive


	\\ *DOUT (<drive>)
	\\ Unload drive
	\\ Note: No error if drive not loaded
.CMD_DOUT
	JSR Param_OptionalDriveNo
	JSR VID_check_report
	LDX CurrentDrv
	TXA				; Bit 7 & 6 clear.
	STA DRIVE_INDEX4,X
	JMP VID_reset_crc


	\\ *DCAT ((<f.dno>) <t.dno>) (<adsp>)
dcEnd%=&A8	; last disk in range
dcCount%=&AA	; number of disks found

.CMD_DCAT
{
	LDA #0
	STA gdopt%			; GetDisk excludes unformatted disks
	STA dcCount%
	STA dcCount%+1

	JSR Param_ReadNum		; rn% @ B0
	BCS dc_1			; not number

	STX dcEnd%
	STX gddiskno%
	STA dcEnd%+1
	STA gddiskno%+1

	JSR Param_ReadNum		; rn% @ B0
	BCS dc_2			; not number

	STX dcEnd%
	STA dcEnd%+1

	CPX gddiskno%
	SBC gddiskno%+1
	BPL dc_3

.badrange
	JSR ReportError
	EQUB &FF
	EQUS "Bad range",0

.dc_1	LDX #&FE
	STX dcEnd%
	INX
	STX dcEnd%+1

.dc_2	LDA #0
	STA gddiskno%
	STA gddiskno%+1

.dc_3	INC dcEnd%
	BNE dc_4

	INC dcEnd%+1

.dc_4	JSR DMatchInit
	JSR GetDiskFirst

	LDX #0
	LDA dmLen%
	BNE dclp

	DEX
	STX dmAmbig%

.dclp	LDA gddiskno%+1
	BMI dcfin

	LDA gddiskno%
	CMP dcEnd%
	LDA gddiskno%+1
	SBC dcEnd%+1
	BCS dcfin

	JSR DMatch
	BCS dcnxt

	JSR PrintDCat

	SED
	CLC
	LDA dcCount%
	ADC #1
	STA dcCount%
	LDA dcCount%+1
	ADC #0
	STA dcCount%+1
	CLD

.dcnxt	JSR CheckESCAPE

.dcdonxt
	JSR GetDiskNext
	JMP dclp

.dcfin	LDA #&86
	JSR OSBYTE			; get cursor pos
	CPX #0
	BEQ dcEven

	JSR PrintNewLine

.dcEven	LDA dcCount%+1
	LDX #0
	LDY #4
	JSR PrintDec
	LDA dcCount%
	JSR PrintDec
	JSR PrintString
	EQUS " disc"
	LDA dcCount%+1
	BNE dcNotOne

	DEC dcCount%
	BEQ dcOne

.dcNotOne
	LDA #&73			; ASC("s")
	JSR PrintChrA

.dcOne
	JSR PrintString
	EQUS " found"
	NOP
	JMP PrintNewLine
}


	\\ *DDRIVE (<drive>)
	\\ List disks in drives
.CMD_DDRIVE
{
	STY &B3

	LDA #&FF
	STA gdopt%			; GetDisk returns unformatted disks

	LDA #3
	STA CurrentDrv			; Last drive to list

	LDY &B3
	JSR GSINIT_A
	BEQ ddsknoparam

	JSR Param_DriveNo_BadDrive
	BCC ddskloop			; always

.ddsknoparam
	LDA #0

	\\ A = drive
.ddskloop
	PHA
	TAX

	\\ print drive no
	LDA #&3A			; ASC(":")
	JSR OSWRCH
	CLC
	TXA
	ADC #&30
	JSR OSWRCH

	LDA #&20
	JSR PrintChrA

	TXA
	PHA
	JSR MMC_Drive_State
	PLA
	TAX
	PHP

	LDA #'R'			; 'R' for real!
	BCC label1			; If real drive

	LDA #'V'			; 'V' for virtual!

.label1	JSR PrintChrA

	PLP
	BCC ddcont			; If real drive

	LDA DRIVE_INDEX4,X
	ROL A
	BPL ddcont 			; If drive empty

	ROR A
	AND #&0F
	STA &B9
	LDA DRIVE_INDEX0,X
	STA &B8
	JSR GetDiskFirst
	CMP #&FF
	BEQ ddcont

	SEC
	JSR PrintDCat

.ddcont	JSR OSNEWL
	PLA
	CMP CurrentDrv
	BEQ ddskexit

	ADC #1
	BCC ddskloop			; always

.ddskexit
	RTS
}


	\\ *DOP (P/U/N/K/R) (<drive>)
	\\ Options: P=Protect, U=Unprotect, N=New, K=Kill, R=Restore
.CMD_DOP
{
	JSR GSINIT_A
	BEQ err

	LDX #(dopex-dop)

.loop	CMP dop,X
	BEQ ok

	DEX
	BPL loop

.err	JMP errBADOPTION

.ok	TXA
	AND #&FE
	TAX

	LDA dopex+1,X
	PHA
	LDA dopex,X
	PHA

	INY
	JMP Param_OptionalDriveNo

.dop	EQUS "rRkKnNuUpP"

.dopex  EQUW dop_Restore-1
	EQUW dop_Kill-1
	EQUW dop_New-1
	EQUW dop_Unprotect-1
	EQUW dop_Protect-1
}


	\\ Mark disk in current drive as formatted
	\\ and clear its disk catalogue entry
	\\ Used by *FORM
.MMC_DiskFormatted
{
	LDX ActiveDrv
	JSR SetCurrentDiskX
	JSR GetDiskStatus

	LDA #0
	TAY

.loop	STA (&B0),Y			; clear title in catalogue
	INY
	CPY #15
	BNE loop

	TYA				; A=&0F Unlocked disk
	BNE masf_status			; always
}


	\\ Mark disk as read only
.dop_Protect
	LDA #&00
	BEQ dlul

	\\ Mark disk as writable
.dop_Unprotect
	LDA #&0F

.dlul	PHA

.dkconfirmed
	JSR GetDriveStatus
	BMI jmpErrNotFormatted

.drestore
	PLA

.masf_status
	LDY #15
	STA (&B0),Y
	JSR SaveDiskTable
	JMP LoadDrive			; reload disk


.jmpErrNotFormatted
	JMP errNotFormatted

.jmpErrFormatted
	JMP errFormatted


	\\ Mark disk as unformatted
.dop_Kill
{
	JSR IsEnabledOrGo
	JSR GetDriveStatus
	JSR CheckWriteProtect
	JSR GetDiskFirst
	JSR PrintString
	EQUS "Kill"
	NOP
	SEC
	JSR PrintDCat
IF sys=120
	JSR PrintString
	EQUS " : "
	NOP
ENDIF
	JSR ConfirmYN
	PHP
	JSR PrintNewLine
	PLP
	BNE dkcancel

	LDA #&F0			; Unformatted disk
	PHA
	JMP dkconfirmed

.dkcancel
	RTS
}

	\\ Mark disk as formatted (without reformatting)
.dop_Restore
	LDA #&0F
	PHA
	SEC 				; disk must be unformatted
	JSR GetDriveStatusC
	BMI drestore

	BPL jmpErrFormatted


	\\ Find first unformatted disk and load in drive
.dop_New
{
	JSR FreeDisk
	BCS ErrNoFreeDisks		; no free disks

	\ load unformatted disk
	JSR LoadDrive

	\ message: disk# in drv#:
	JSR PrintString
	EQUS "Disc "

	LDX #0
	JSR DecNo_Print

	JSR PrintString
	EQUS " in :"

	LDA CurrentDrv
	LDX #0
	LDY #2
	JSR PrintDec
	JMP OSNEWL

.ErrNoFreeDisks
	JSR ReportError
	EQUB &FF
	EQUS "No free discs",0


	\\**** Find first free disk ****
	\\ On exit: Word &B8=disk number
	\\ C=0=Found / C=1=Not Found
.FreeDisk
{
	LDA #&FF
	STA gdopt%			; GetDisk returns unformatted disk

	JSR GetDiskFirstAll
	BCS notfound

	CMP #&F0			; Is it formatted?
	BEQ found			; No!

.loop	JSR GetDiskNext
	BCS notfound

	CMP #&F0
	BNE loop

.found	CLC

.notfound
	RTS
}
}


\ End of file

