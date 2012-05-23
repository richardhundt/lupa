LIBDIR=./lib
SRCDIR=./src
INCDIR=./include
BINDIR=./bin
DEPSDIR=./deps
BUILDDIR=./build
LPEGDIR=${DEPSDIR}/lpeg
LMARDIR=${DEPSDIR}/lua-marshal
LUADIR=${DEPSDIR}/luajit
UVDIR=${DEPSDIR}/libuv

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

BUILD= ${BUILDDIR}/bin/lupa

all: ${BINDIR}/luajit ${BINDIR}/lupa ${LIBDIR}/lpeg.so ${LIBDIR}/marshal.so ${LIBDIR}/libuv.so ${BUILD}

${BINDIR}/lupa:
	mkdir -p ${BINDIR}
	${CC} ${CFLAGS} -I${LUADIR}/src -L${LUADIR}/src -o ${BINDIR}/lupa ./src/lupa.c ${LIBDIR}/libluajit.a ${LDFLAGS}

${BUILDDIR}/bin/lupa:
	mkdir -p ${BUILDDIR}/bin
	${CC} ${CFLAGS} -I${LUADIR}/src -L${LUADIR}/src -o ${BUILDDIR}/bin/lupa ./src/lupa.c ${LIBDIR}/libluajit.a ${LDFLAGS}

${LIBDIR}/lpeg.so:
	${MAKE} -C ${LPEGDIR} lpeg.so
	cp ${LPEGDIR}/lpeg.so ${LIBDIR}/lpeg.so

${LIBDIR}/libuv.so:
	git submodule update --init ${UVDIR}
	${MAKE} -C ${UVDIR}
	mkdir -p ${BUILDDIR}/uv
	cp ${UVDIR}/uv.a ${BUILDDIR}/uv/uv.a
	cd ${BUILDDIR}/uv/ && ar -x uv.a
	mkdir -p ${INCDIR}
	${CC} -I${UVDIR}/include ${UVDIR}/include/uv.h -E | grep -v '#' >${INCDIR}/uv.h
	${CC} -I${UVDIR}/include -undefined dynamic_lookup -shared -o ${LIBDIR}/libuv.so ${BUILDDIR}/uv/*.o

${LIBDIR}/marshal.so:
	git submodule update --init ${LMARDIR}
	${MAKE} -C ${LMARDIR} marshal.so
	cp ${LMARDIR}/marshal.so ${LIBDIR}/marshal.so

${LIBDIR}/libluajit.a:
	git submodule update --init ${LUADIR}
	${MAKE} -C ${LUADIR}
	cp ${LUADIR}/src/libluajit.a ${LIBDIR}/libluajit.a

${BINDIR}/luajit: ${LIBDIR}/libluajit.a
	mkdir -p ${BINDIR}
	cp ${LUADIR}/src/luajit ${BINDIR}/luajit

clean:
	${MAKE} -C ${LUADIR} clean
	${MAKE} -C ${LPEGDIR} clean
	${MAKE} -C ${LMARDIR} clean
	${MAKE} -C ${UVDIR} clean
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
	${LUADIR}/src/luajit -b -g ${BUILDDIR}/lupa.lua ./src/lupa.h
	${LUADIR}/src/luajit -b -g ${BUILDDIR}/predef.lua ./src/predef.h
	${LUADIR}/src/luajit -b -g ${BUILDDIR}/compiler.lua ./src/compiler.h
	cp ${BUILDDIR}/bin/lupa ${BINDIR}

.PHONY: all clean bootstrap

