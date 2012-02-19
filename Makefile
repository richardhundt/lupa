LIBDIR=./lib
SRCDIR=./src
DEPDIR=./deps
BUILDDIR=./build
LPEGDIR=${DEPDIR}/lpeg
LUADIR=${DEPDIR}/luajit

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

CFLAGS=-O2 -fomit-frame-pointer -Wall -g -fno-stack-protector
LDFLAGS=-lm -ldl

ifeq (${OS_NAME}, Darwin)
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000
endif
else ifeq (${OS_NAME}, Linux)
CFLAGS+=-Wl,-E
endif

XCFLAGS=-g
XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS

all: ${LIBDIR}/lpeg.so ${LIBDIR}/libluajit.a ${BUILDDIR}/lupa

${BUILDDIR}/lupa:
	mkdir -p ${BUILDDIR}
	${CC} ${CFLAGS} -I${LUADIR}/src -L${LUADIR}/src -o ${BUILDDIR}/lupa ./src/lupa.c ${LIBDIR}/libluajit.a ${LDFLAGS}

${LIBDIR}/lpeg.so:
	${MAKE} -C ${LPEGDIR} lpeg.so
	cp ${LPEGDIR}/lpeg.so ${LIBDIR}/lpeg.so

${LIBDIR}/libluajit.a:
	git submodule update --init ${LUADIR}
	${MAKE} -C ${LUADIR}
	cp ${LUADIR}/src/libluajit.a ${LIBDIR}/libluajit.a

clean:
	${MAKE} -C ${LUADIR} clean
	${MAKE} -C ${LPEGDIR} clean
	rm -f ${LIBDIR}/*.so
	rm -f ${LIBDIR}/*.a
	rm -f ${BUILDDIR}/lupa

bootstrap: all
	${BUILDDIR}/lupa lupa.lu -o ${BUILDDIR}/lupa.lua
	mv ./src/lupa.h ./src/lupa.h.bak
	${LUADIR}/src/luajit -b ${BUILDDIR}/lupa.lua ./src/lupa.h

.PHONY: all clean bootstrap

