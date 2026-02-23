SIM ?= verilator
TOPLEVEL_LANG = verilog

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = $(DUT)
# MODULE is the basename of the Python test file
COCOTB_TEST_MODULES = sim
VERILOG_SOURCES += $(DUT).sv ../axi_lite_if.sv ../axi_lite_csr_w1c.sv

# warnings
COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
# waveforms
EXTRA_ARGS += --trace --trace-fst --trace-threads 2 --trace-structs
EXTRA_ARGS += --threads 6
EXTRA_ARGS += -DINTF_TYPE=axi_lite_if -DDUT_NAME=axi_lite_csr_w1c

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: bus waves

test:
	$(MAKE) DUT=wrapper_template -j10

waves:
	@test -f sim_build/dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer -s state.surf.ron sim_build/dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
