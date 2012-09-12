
OS_NAME=$(shell uname -s)

SYSOPT=

ifeq (${OS_NAME}, Darwin)
SYSOPT+=osx
endif

ifeq (${OS_NAME}, Linux)
SYSOPT+=linux
endif

ifeq (${OS_NAME}, GNU/kFreeBSD)
SYSOPT+=bsd
endif


all: sys

sys:
	git submodule update --init ./inc
	${MAKE} -C ./inc/src ${SYSOPT}
	cp ./inc/src/sys.so ../sys.so

clean:
	${MAKE} -C ./inc/src clean

.PHONY: all sys clean

