SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= fifo
# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = $(DUT)
# MODULE is the basename of the Python test file
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../$(DUT).sv

# warnings
COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
# waveforms
EXTRA_ARGS += --trace --trace-fst --trace-threads 2 --trace-structs
EXTRA_ARGS += --threads 6

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: fifo waves

fifo: export COMPILE_ARGS := $(COMPILE_ARGS) -GWIDTH=8 -GDEPTH=16 -GALMOST_EMPTY_THRESHOLD=1
fifo:
	$(MAKE) DUT=fifo -j10

spec_fifo: export COMPILE_ARGS := $(COMPILE_ARGS) -GWIDTH=8 -GDEPTH=32
spec_fifo:
	$(MAKE) DUT=spec_fifo -j10

bus_incr:
	$(MAKE) DUT=bus_width_increase -j10

bus_dec:
	$(MAKE) DUT=bus_width_decrease -j10

waves:
	@test -f dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer -s state.surf.ron dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
