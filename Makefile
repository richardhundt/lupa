SRCDIR=./src
BLDDIR=./build
LPEGDIR=./deps/lpeg
LUADIR=./deps/luajit
LIBDIR=./lib
BINDIR=${BLDDIR}/bin

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

CFLAGS=-O2 -Wall
LDFLAGS=-lluajit -lstdc++ -lm -ldl -lpthread

ifeq (${OS_NAME}, Darwin)
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000 -framework CoreServices
endif
else
CFLAGS+=-Wl,-E -fomit-frame-pointer -fno-stack-protector
LDFLAGS+=-lrt
endif

INCS=-I${LUADIR}/src -L${LUADIR}/src
DEPS=${LUADIR}/src/libluajit.a ${LIBDIR}/lpeg.so

all: ${BINDIR}/lupa

${BINDIR}/lupa: ${DEPS}
	mkdir -p ${BLDDIR}
	mkdir -p ${BINDIR}
	${CC} ${CFLAGS} ${INCS} -o ${BINDIR}/lupa ${SRCDIR}/lib_init.c ${SRCDIR}/lupa.c ${LUADIR}/src/libluajit.a ${LPEGDIR}/lpeg.o ${LDFLAGS}

${LUADIR}/src/libluajit.a:
	git submodule update --init ${LUADIR}
	${MAKE} XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT" -C ${LUADIR}

${LIBDIR}/lpeg.so:
	${MAKE} -C ${LPEGDIR}
	cp ${LPEGDIR}/lpeg.so ${LIBDIR}/lpeg.so

clean:
	rm -rf ${BLDDIR}
	rm -f ./lib/*.so

realclean: clean
	${MAKE} -C ${LUADIR} clean
	${MAKE} -C ${LUVDIR} realclean

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
	mkdir -p ./lib/lupa
	${LUADIR}/src/luajit -b -g ${BLDDIR}/core.lua ./lib/lupa/core.lua
	${LUADIR}/src/luajit -b -g ${BLDDIR}/lang.lua ./lib/lupa/lang.lua

install: all
	mkdir -p /usr/local/bin
	cp ./build/bin/lupa /usr/local/bin/lupa
	mkdir -p /usr/local/lib/lupa/std
	cp ./std/*.lu /usr/local/lib/lupa/std
	cp ./lib/*.so /usr/local/lib/lupa

.PHONY: all clean realclean bootstrap install

