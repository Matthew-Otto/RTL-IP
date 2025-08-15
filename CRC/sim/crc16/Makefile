SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= crc16
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

.PHONY: crc16 waves

crc16: export COMPILE_ARGS := $(COMPILE_ARGS) -GPOLYNOMIAL=0x1021
crc16:
	$(MAKE) DUT=crc16 -j10

waves:
	@test -f dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
