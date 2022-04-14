	\-------------------------------------------------------------------\
	\ Title   : Ultra DFS                                               \
	\ Author  : Martin Mather 2015                                      \
	\ Compiler: BeebAsm V1.08                                           \
	\-------------------------------------------------------------------\
	\ Module  : mmc_dutils.asm                                          \
	\-------------------------------------------------------------------\


	\\ *DABOUT -  PRINT INFO STRING
.CMD_DABOUT
	JSR PrtString
	EQUS "DUTILS by Martin Mather (2015)", 13, 10
	NOP
	RTS


	\\ *DIN (<drive>) <dno/dname>
	\\ Insert virtual disk into drive.
.CMD_DIN
	JSR Param_DriveAndDisk
	JMP mmc_load_drive 			;CA


	\\ *DOUT (<drive>)
	\\ Remove virtual disk from drive:
	\\ drive returns to being a physical drive.
	\\ Note: No error if drive not loaded
.CMD_DOUT
	JSR Param_OptionalDriveNo		;Get drive number.
	JMP mmc_unload_drive
