SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= fifo_w1r4
# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = $(DUT)
# MODULE is the basename of the Python test file
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../$(DUT).sv

# warnings
COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
# waveforms
EXTRA_ARGS += --trace  --trace-threads 2 --trace-structs #--trace-fst
EXTRA_ARGS += --threads 6


include $(shell cocotb-config --makefiles)/Makefile.sim

test:
	$(MAKE) -j10

waves:
	@test -f dump.vcd || (echo "Error: dump.vcd not found. Simulate a target first." && exit 1)
	surfer -s state.surf.ron dump.vcd

clean::
	rm -rf __pycache__
	rm -f results.xml
