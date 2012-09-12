LIBNAME = lpeg
LUADIR = /usr/include/lua5.1/

COPT = -O2 -DNDEBUG -fPIC

CWARNS = -Wall -Wextra -pedantic \
        -Waggregate-return \
	-Wbad-function-cast \
        -Wcast-align \
        -Wcast-qual \
	-Wdeclaration-after-statement \
	-Wdisabled-optimization \
        -Wmissing-prototypes \
        -Wnested-externs \
        -Wpointer-arith \
        -Wshadow \
	-Wsign-compare \
	-Wstrict-prototypes \
	-Wundef \
        -Wwrite-strings \
	#  -Wunreachable-code \


OS_NAME=$(shell uname -s)

CFLAGS = $(CWARNS) $(COPT) -ansi -I$(LUADIR)
CC = gcc

ifeq ($(OS_NAME), Darwin)
ENV=MACOSX_DEPLOYMENT_TARGET=10.4
DLLFLAGS=-bundle -undefined dynamic_lookup
else
DLLFLAGS=-shared -fPIC
ENV= 
endif

lpeg.so: lpeg.o
	env $(ENV) $(CC) $(CFLAGS) $(DLLFLAGS) lpeg.o -o lpeg.so

lpeg.o:		Makefile lpeg.c lpeg.h

test: test.lua re.lua lpeg.so
	lua test.lua
clean:
	rm -f *.o *.so
