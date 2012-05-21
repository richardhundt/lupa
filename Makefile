LIBDIR=./lib
SRCDIR=./src
INCDIR=./include
BINDIR=./bin
DEPSDIR=./deps
BUILDDIR=./build
LPEGDIR=${DEPSDIR}/lpeg
LMARDIR=${DEPSDIR}/lua-marshal
LUADIR=${DEPSDIR}/luajit
LLTDIR=${DEPSDIR}/llthreads
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

#cc -I./deps/libuv/include -undefined dynamic_lookup -shared -o ./lib/libuv.so ./deps/libuv/uv/*.o

all: ${BINDIR}/luajit ${BUILDDIR}/bin/lupa ${LIBDIR}/lpeg.so ${LIBDIR}/marshal.so ${LIBDIR}/libuv.so

${BUILDDIR}/bin/lupa: ${BUILDDIR}/lupa/predef.lua ${BUILDDIR}/lupa/compiler.lua
	mkdir -p ${BUILDDIR}/bin
	${CC} ${CFLAGS} -I${LUADIR}/src -L${LUADIR}/src -o ${BUILDDIR}/bin/lupa ./src/lupa.c ${LIBDIR}/libluajit.a ${LDFLAGS}

${BUILDDIR}/lupa/predef.lua:
	mkdir -p ${BUILDDIR}/lupa
	${BINDIR}/luajit -b ./src/lupa/predef.lua ${BUILDDIR}/lupa/predef.lua

${BUILDDIR}/lupa/compiler.lua:
	mkdir -p ${BUILDDIR}/lupa
	${BINDIR}/lupa ./src/lupa/compiler.lu -b ${BUILDDIR}/lupa/compiler.lua

${LIBDIR}/lpeg.so:
	${MAKE} -C ${LPEGDIR} lpeg.so
	cp ${LPEGDIR}/lpeg.so ${LIBDIR}/lpeg.so

${LIBDIR}/libuv.so:
	${MAKE} -C ${UVDIR}
	mkdir -p ${BUILDDIR}/uv
	cp ${UVDIR}/uv.a ${BUILDDIR}/uv/uv.a
	cd ${BUILDDIR}/uv/ && ar -x uv.a
	${CC} -I${UVDIR}/include ${UVDIR}/include/uv.h -E | grep -v '#' >${INCDIR}/uv.h
	${CC} -I${UVDIR}/include -undefined dynamic_lookup -shared -o ${LIBDIR}/libuv.so ${BUILDDIR}/uv/*.o

${LIBDIR}/marshal.so:
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
	rm -f ${BUILDDIR}/lupa/*
	rm -f ${BUILDDIR}/bin/*
	rm -f ${LIBDIR}/*.so
	rm -f ${LIBDIR}/*.a

bootstrap: all
	${BINDIR}/lupa ./src/lupa.lu -o ${BUILDDIR}/lupa.lua
	mv ./src/lupa.h ./src/lupa.h.bak
	${LUADIR}/src/luajit -b ${BUILDDIR}/lupa.lua ./src/lupa.h
	mkdir -p lupa
	cp -r ${BUILDDIR}/lupa/* ./lupa/
	cp ${BUILDDIR}/bin/lupa ./bin/

.PHONY: all clean bootstrap

