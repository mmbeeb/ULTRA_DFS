	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2016                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : MMC_eq.asm                                              \
	\-------------------------------------------------------------------\


	mmc%=&FE18


	\\ MMC Commands

	go_idle_state     = &40
	send_op_cond      = &41
	send_cid          = &4A
	set_blklen        = &50
	read_single_block = &51
	write_block       = &58


datptr%=&BC
sec%=&BE
seccount%=&C1
skipsec%=&C2
byteslastsec%=&C3

cmdseq%=swsp+&1087
par%=swsp+&1089
TubeNoTransferIf0=NotTUBEOpIf0	;10D5	;swsp+&109E	;????
CurrentCat=swsp+&1082

buf%=swsp+&E00
cat%=swsp+&E00


	MA=swsp
	MP=LO(swsp+&E00)



	\\ MMC State

	MMC_STATE = VAL_1084	;If MMC_STATE_ON then card initialised.
				;(previously if bit 6 set...)
				;(Note: VAL_1084 defined in filesys_eq.asm.)

	MMC_STATE_OFF     = &00
	MMC_STATE_ON      = &5A


	\\ MMC Workspace

	\\ 1000-103F is used by the DFS as a string buffer, as well as general workspace.

	mmc_strbuf = swsp + &1000

	


read16sec%=&B3	; 3 byte sector value
read16str%=mmc_strbuf ;MA+&1000


	\\ 1090-109F (also used by the 1770 code)

;	MMC_WSP = OWCtlBlock ;1090-109F 16 bytes of workspace

	\\ Workspace bytes &A0 to &BF are not used by the DFS
	\\ (i.e. &10A0 to &10BF and pws+&A0 to pws+&BF).

	ORG swsp + &10A0

	\ 10A0-10AF : Very Important Data (VID)
	\ If this gets corrupted, user will need to do a reset.
.VID

.DRIVE_INDEX0	SKIP 4	;10A0-10A3 Bits 0 to 7 of DRIVE_INDEX.
.DRIVE_INDEX4	SKIP 4	;10A4-10A7 Bits 8 to 15 of DRIVE INDEX.
.MMC_SECTOR	SKIP 3	;10A8-10AA MMB file first sector.
.MMC_CIDCRC	SKIP 2	;10AB-10AC CRC of MMC card's CID.
		SKIP 2	;10AD-10AE Not used.
.VID_CRC	SKIP 1	;10AF CRC7 of VID.

.MMC_WSP	SKIP 16	;Workspace
			;10B0-10B9 used by MMC_BEGIN/MMC_END to
			;preserve locations B0-B9.

	VID_SIZE = VID_CRC - VID + 1


\ DRIVE_INDEX (old version)
\ Bit 15 = Disk loaded
\ Bit 14 = Write Protected
\ Bit 13
\ Bit 12

\ Bit 11 = Unformatted
\ Bits 0 to 16 = disk number



\ DRIVE_INDEX (ultra version)
\ Bit 15 = Virtual Drive (if clear disregard all other bits).
\ Bit 14 = Disc loaded
\ Bit 13 = Write Protected
\ Bit 12 = Unformatted

\ Bits 0 to 11 = Disc number