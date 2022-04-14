	\\ Acorn DFS 2.24
	\\ Ultra224.asm
	\\ Compiler: BeebAsm V1.08
	\\ Disassembly by Martin Mather

	_MMC_DEVICE_ = 'M'

	sys=224
	ultra = TRUE

	ultra2=FALSE
	INCLUDE "dfs.asm"

	SAVE "ULTRA224.ROM", &8000, &C000
