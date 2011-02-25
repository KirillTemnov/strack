.PHONY: all clean

all:
	coffee -b -c *.coffee
	coffee -b -c lib/*.coffee
clean:
	rm *.js
	rm lib/*.js