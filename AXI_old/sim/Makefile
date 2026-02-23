SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= axi4_lite_bus
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

.PHONY: bus waves

bus: export COMPILE_ARGS := $(COMPILE_ARGS) -GNUM_MASTERS=2 -GNUM_SLAVES=2 -GBASE_ADDRS=0x00001000 -GADDR_MASKS=0xff00ff00
bus:
	$(MAKE) DUT=axi4_lite_bus -j10

write_master:
	$(MAKE) DUT=axi_lite_write_master -j10

read_master:
	$(MAKE) DUT=axi_lite_read_master -j10

waves:
	@test -f dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer -s state.surf.ron dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
