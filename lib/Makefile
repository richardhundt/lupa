
LIBS=lpeg.so sys.so

all: ${LIBS}

lpeg.so:
	${MAKE} -C ./lpeg
	cp ./lpeg/lpeg.so ./lpeg.so

sys.so:
	${MAKE} -C ./sys

clean:
	${MAKE} -C ./sys clean
	${MAKE} -C ./lpeg clean
	rm -f *.so *.a

.PHONY: all clean

