	\\ Ultra DFS 1.20
	\\ ultra120.asm
	\\ Compiler: BeebAsm V1.08
	\\ by Martin Mather

	_MMC_DEVICE_ = 'U'

	sys=120
	ultra = TRUE

	INCLUDE "dfs.asm"

	SAVE "U120UP.ROM", &8000, &C000
