#
# rule: do not use @ to hide commands
#

#generated by ./configure
include autoconf/Makefile.config

OPAMDEPS=yojson menhir ocp-build

OCPBUILD=ocp-build
OCAMLOPT=ocamlopt.opt
OCAMLC=ocamlc
SRC=src

all:
	if [ ! -d "_obuild" ]; then $(OCPBUILD) init; fi
	$(OCPBUILD)

test:
	@./_obuild/testsuite/testsuite.asm \
	./_obuild/ocp-lint/ocp-lint.asm \
	testsuite

clean:
	$(OCPBUILD) clean

cleanall: distclean

distclean:
	rm -f autoconf/config.log
	rm -f autoconf/Makefile.config
	rm -f autoconf/config.log
	rm -f autoconf/config.ocpgen
	rm -f autoconf/config.status
	rm -rf autoconf/autom4te.cache
	rm -rf _obuild/

opam-deps:
	opam install $(OPAMDEPS)

install:
	cp _obuild/ocp-lint/ocp-lint.asm $(BINDIR)/ocp-lint


