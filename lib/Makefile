
LIBS=lpeg.so

all: ${LIBS}

lpeg.so:
	${MAKE} -C ./lpeg
	cp ./lpeg/lpeg.so ./lpeg.so

clean:
	${MAKE} -C ./lpeg clean
	rm -f *.so *.a

.PHONY: all clean

