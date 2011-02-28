.PHONY: all clean

all:
	coffee -b -c lib/*.coffee

install:
	npm install coffee-script
	coffee -b -c lib/*.coffee

clean:
	rm lib/*.js