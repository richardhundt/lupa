SRCDIR=./src
BLDDIR=./build
LUADIR=./deps/luajit
LIBDIR=./lib
BINDIR=${BLDDIR}/bin

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

CFLAGS=-O2 -fomit-frame-pointer -Wall -fno-stack-protector
LDFLAGS=-lm -ldl

ifeq (${OS_NAME}, Darwin)
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000
endif
else
CFLAGS+=-Wl,-E
endif

DEPS=${LUADIR}/src/libluajit.a ${LIBDIR}/lpeg/lpeg.o

all: ${BINDIR}/lupa

${BINDIR}/lupa: ${DEPS} libs
	mkdir -p ${BLDDIR}
	mkdir -p ${BINDIR}
	${CC} ${CFLAGS} -I${LUADIR}/src -L${LUADIR}/src -o ${BINDIR}/lupa ${SRCDIR}/lib_init.c ${SRCDIR}/lupa.c ${DEPS} ${LDFLAGS}

libs:
	${MAKE} -C ${LIBDIR}

${LUADIR}/src/libluajit.a:
	git submodule update --init ${LUADIR}
	${MAKE} XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" -C ${LUADIR}

clean:
	${MAKE} -C ${LUADIR} clean
	${MAKE} -C ${LIBDIR} clean
	rm -rf ${BLDDIR}

bootstrap: all
	${BINDIR}/lupa ./src/lupa.lu -o ${BLDDIR}/lupa.lua
	${BINDIR}/lupa ./src/lupa/lang.lu -o ${BLDDIR}/lang.lua
	cp ./src/lupa/core.lua ${BLDDIR}/core.lua
	cp ./src/lupa.h ./src/lupa.h.bak
	cp ./src/core.h ./src/core.h.bak
	cp ./src/lang.h ./src/lang.h.bak
	cp ${BINDIR}/lupa ${BINDIR}/lupa.bak
	${LUADIR}/src/luajit -b -g ${BLDDIR}/lupa.lua ./src/lupa.h
	${LUADIR}/src/luajit -b -g ${BLDDIR}/core.lua ./src/core.h
	${LUADIR}/src/luajit -b -g ${BLDDIR}/lang.lua ./src/lang.h

install: all
	mkdir -p /usr/local/bin
	cp ./build/bin/lupa /usr/local/bin/lupa
	mkdir -p /usr/local/lib/lupa/std
	cp ./std/*.lu /usr/local/lib/lupa/std
	cp ./lib/*.so /usr/local/lib/lupa

.PHONY: all clean bootstrap install libs

