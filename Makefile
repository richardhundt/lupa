LIBDIR=./lib
SRCDIR=./src
INCDIR=./include
BINDIR=./bin
DEPSDIR=./deps
BUILDDIR=./build
LPEGDIR=${DEPSDIR}/lpeg
LUADIR=${DEPSDIR}/luajit

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

CFLAGS=-O2 -fomit-frame-pointer -Wall -g -fno-stack-protector
LDFLAGS=-lm -ldl
DEPS=${LIBDIR}/libluajit.a ${LPEGDIR}/lpeg.o

ifeq (${OS_NAME}, Darwin)
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000
endif
else
CFLAGS+=-Wl,-E
endif

XCFLAGS=-g
XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
#XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS

BUILD= ${BUILDDIR}/bin/lupa

all: ${BINDIR}/luajit ${BINDIR}/lupa ${LPEGDIR}/lpeg.o ${BUILD}

${BINDIR}/lupa: ${BUILDDIR}/bin/lupa
	mkdir -p ${BINDIR}
	cp ${BUILDDIR}/bin/lupa ${BINDIR}/lupa

${BUILDDIR}/bin/lupa: ${DEPS}
	mkdir -p ${BUILDDIR}/bin
	${CC} ${CFLAGS} -I${LPEGDIR} -I${LUADIR}/src -L${LUADIR}/src -o ${BUILDDIR}/bin/lupa ./src/lib_init.c ./src/lupa.c ${DEPS} ${LDFLAGS}

${LPEGDIR}/lpeg.o:
	${MAKE} -C ${LPEGDIR} lpeg.o

${LIBDIR}/libluajit.a:
	git submodule update --init ${LUADIR}
	${MAKE} XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" -C ${LUADIR}
	cp ${LUADIR}/src/libluajit.a ${LIBDIR}/libluajit.a

${BINDIR}/luajit: ${LIBDIR}/libluajit.a
	mkdir -p ${BINDIR}
	cp ${LUADIR}/src/luajit ${BINDIR}/luajit

clean:
	${MAKE} -C ${LUADIR} clean
	${MAKE} -C ${LPEGDIR} clean
	rm -rf ${BUILDDIR}
	rm -f ${LIBDIR}/*.so
	rm -f ${LIBDIR}/*.a

bootstrap: all
	${BINDIR}/lupa ./src/lupa.lu -o ${BUILDDIR}/lupa.lua
	${BINDIR}/lupa ./src/lupa/compiler.lu -o ${BUILDDIR}/compiler.lua
	cp ./src/lupa/predef.lua ${BUILDDIR}/predef.lua
	mv ./src/lupa.h ./src/lupa.h.bak
	mv ./src/predef.h ./src/predef.h.bak
	mv ./src/compiler.h ./src/compiler.h.bak
	mv ${BINDIR}/lupa ${BINDIR}/lupa.bak
	${LUADIR}/src/luajit -b ${BUILDDIR}/lupa.lua ./src/lupa.h
	${LUADIR}/src/luajit -b ${BUILDDIR}/predef.lua ./src/predef.h
	${LUADIR}/src/luajit -b ${BUILDDIR}/compiler.lua ./src/compiler.h
	cp ${BUILDDIR}/bin/lupa ${BINDIR}

install: all
	mkdir -p /usr/local/bin
	cp ./build/bin/lupa /usr/local/bin/lupa
	mkdir -p /usr/local/lib/lupa/std
	cp ./std/*.lu /usr/local/lib/lupa/std

.PHONY: all clean bootstrap install

