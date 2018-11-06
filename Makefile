.PHONY: all clean clean-all compile doc dialyzer xref ci

REBAR3 ?= rebar3

all: compile xref

ci: compile xref dialyzer

compile:
	$(REBAR3) compile

clean: clean_plt
	$(REBAR3) clean

clean-all: clean
	rm -rf _build

xref:
	$(REBAR3) xref

doc:
	$(REBAR3) as docs do edoc

dialyzer:
	$(REBAR3) dialyzer
