
OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

CFLAGS=-O2 -fomit-frame-pointer -Wall -fno-stack-protector
LDFLAGS=-lm -ldl
SYSOPT=

ifeq (${OS_NAME}, Darwin)
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-undefined dynamic_lookup -framework CoreServices
endif
SYSOPT+=osx
else
CFLAGS+=-shared -Wl,-E
SYSOPT+=linux
endif

all: sys

sys:
	${MAKE} -C ./inc/src ${SYSOPT}
	cp ./inc/src/sys.so ../sys.so

clean:
	${MAKE} -C ./inc/src clean

.PHONY: all sys clean

