LIBDIR=./lib
DEPDIR=./deps
BINDIR=./bin
LPEGDIR=${DEPDIR}/lpeg
LJ2DIR=${DEPDIR}/luajit

XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS

all: ${LIBDIR}/lpeg.so ${BINDIR}/luajit

${LIBDIR}/lpeg.so:
	${MAKE} -C ${LPEGDIR} lpeg.so
	cp ${LPEGDIR}/lpeg.so ${LIBDIR}/lpeg.so

${BINDIR}/luajit:
	git submodule update --init ${LJ2DIR}
	${MAKE} -C ${LJ2DIR}
	cp ${LJ2DIR}/src/luajit ${BINDIR}/luajit

.PHONY: all
