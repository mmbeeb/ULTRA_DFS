	\\ Acorn DFS
	\\ filesys_eq.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

	\\ NMI Workspace

	ORG &A0

.NMI_PrevNMIOwner	SKIP 1	;A0

IF sys<200
.NMI_FDCcmd		SKIP 1	;A1
.NMI_RW_attempts	SKIP 1	;A2
.NMI_Counter1		SKIP 1	;A3
.NMI_Counter2		SKIP 1	;A4
.NMI_Counter3		SKIP 1	;A5
.NMI_DataPointer	SKIP 1	;A6
ELSE
.NMI_Flags		SKIP 1	;A1
.NMI_FDCresult		SKIP 1	;A2
.NMI_SecsPerTrk		SKIP 1	;A3
.NMI_Timings		SKIP 1	;A4
.NMI_SecCounter		SKIP 1	;A5
.NMI_ByteCounter	SKIP 1	;A6
.NMI_FDCcommand		SKIP 1	;A7
ENDIF

	\\ Zero Page

IF ultra
	cmdtab_flag=&BE
ENDIF

IF sys>120 OR ultra
	LastCommand=&BF
ELSE
	LastCommand=&BC
ENDIF

	ORG &CC

.DirectoryParam		SKIP 1	;CC
.CurrentDrv		SKIP 1	;CD
.Track			SKIP 1	;CE
.Sector			SKIP 1	;CF

	\\ Static workspace offset

IF sys=224
	swsp=&C000-&0E00		;MASTER
ELSE
	swsp=0
ENDIF

	FilesX8=swsp+&0F05

	ORG swsp+&1000

	\ 1000-103F is used as a string buffer, as well as general workspace.

.VAL_1000		SKIP 1	;1000
.VAL_1001		SKIP 1	;1001
.VAL_1002		SKIP 1	;1002
.VAL_1003		SKIP 1	;1003
.VAL_1004		SKIP 1	;1004
.VAL_1005		SKIP 1	;1005
.VAL_1006		SKIP 1	;1006
.VAL_1007		SKIP 7	;1007-100D
.VAL_100E		SKIP 50	;100E-103F

.VAL_1040		SKIP 5	;1040-1044
.VAL_1045		SKIP 2	;1045-1046
.VAL_1047		SKIP 6	;1047-104C
.VAL_104D		SKIP 1	;104D
.VAL_104E		SKIP 1	;104E
			SKIP 1	;104F?

.VAL_1050		SKIP 8	;1050-1057
.VAL_1058		SKIP 7	;1058-105E
.VAL_105F		SKIP 1	;105F

.VAL_1060		SKIP 1	;1060
.VAL_1061		SKIP 1	;1061
.VAL_1062		SKIP 1	;1062
.VAL_1063		SKIP 1	;1063
.VAL_1064		SKIP 1	;1064
.VAL_1065		SKIP 1	;1065?
.VAL_1066		SKIP 1	;1066?
.VAL_1067		SKIP 1	;1067
.VAL_1068		SKIP 1	;1068?
.VAL_1069		SKIP 4	;1069-106C
			SKIP 3	;106D-106F?

			SKIP 2	;1070-1071?
.VAL_1072		SKIP 1	;1072
.VAL_1073		SKIP 1	;1073
.VAL_1074		SKIP 1	;1074
.VAL_1075		SKIP 1	;1075
.VAL_1076		SKIP 1	;1076
.VAL_1077		SKIP 1	;1077
.VAL_1078		SKIP 1	;1078
.VAL_1079		SKIP 1	;1079
.VAL_107A		SKIP 1	;107A
			SKIP 1	;107B?
.VAL_107C		SKIP 1	;107C
.VAL_107D		SKIP 1	;107D
.VAL_107E		SKIP 1	;107E
.VAL_107F		SKIP 1	;107F

.TubeOpCode		SKIP 1	;1080
.IsTubeGBPB		SKIP 1	;1081
.LoadedCatDrive		SKIP 1	;1082 Drive Nr
.IsDriveReady		SKIP 1	;1083 Drive Nr (8271 only)
.VAL_1084		SKIP 1	;1084 Not used by DFS (used by Ultra for MMC_STATE)
.VAL_1085		SKIP 1	;1085
.VAL_1086		SKIP 1	;1086

	\ These are used for 8271 emulation:
.VAL_1087		SKIP 1	;1087
.CURRENT_TRACK		SKIP 2	;1088-1089
.VAL_108A		SKIP 1	;108A
.BAD_TRACKS		SKIP 4	;108B-108E
			SKIP 1	;108F?

	\ This block (16 bytes) is used by the 1770 code for
	\ temporary workspace.
.OWCtlBlock		SKIP 16	;1090 OSWORD &7F style control block

	\ These two blocks aren't used by DFS.
			;SKIP 16	;10A0 not used?
			;SKIP 16	;10B0 not used?

	\ ** Note &10C0 to &11BF copied to/from private workspace. **

	ORG swsp+&10C0

.VAL_10C0		SKIP 1	;10C0
.VAL_10C1		SKIP 1	;10C1
.VAL_10C2		SKIP 1	;10C2
.VAL_10C3		SKIP 1	;10C3
.VAL_10C4		SKIP 1	;10C4
.VAL_10C5		SKIP 1	;10C5
.FSMessagesOnIfZero	SKIP 1	;10C6
.CMDEnabledIf1		SKIP 1	;10C7
.NMIstatus		SKIP 1	;10C8
.DEFAULT_DIR		SKIP 1	;10C9
.DEFAULT_DRIVE		SKIP 1	;10CA
.LIB_DIR		SKIP 1	;10CB
.LIB_DRIVE		SKIP 1	;10CC
.VAL_10CD		SKIP 1	;10CD
.VAL_10CE		SKIP 1	;10CE
.PAGE			SKIP 1	;10CF

.RAM_AVAILABLE		SKIP 1	;10D0
.SRC_DRIVE		SKIP 1	;10D1
.DEST_DRIVE		SKIP 1	;10D2
.FORCE_RESET		SKIP 1	;10D3 If +ve: reset DFS on BREAK.
.PWSP_FULL		SKIP 1	;10D4 If +ve: private workspace full.
.NotTUBEOpIf0		SKIP 1	;10D5
.TubePresentIf0		SKIP 1	;10D6
.VAL_10D7		SKIP 1	;10D7
.VAL_10D8		SKIP 1	;10D8
.VAL_10D9		SKIP 1	;10D9
.VAL_10DA		SKIP 1	;10DA
.VAL_10DB		SKIP 1	;10DB
.VAL_10DC		SKIP 1	;10DC
.WRITING_BUFFER		SKIP 1	;10DD

	\ 1770 versions only:
.DRIVE_MODE		SKIP 2	;10DE-10DF DRIVE 0/1

			SKIP 2	;10E0-10E1?
.TRAP_JMP		SKIP 3	;10E2-10E4 Used by OSBYTE trap code.
			SKIP 27	;10E5-10FF not used by DFS.



\\ End of file
