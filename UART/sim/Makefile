# https://github.com/cocotb/cocotb/blob/61abf5c9c0a9e9f120b7b8d31a43ea621241d878/src/cocotb_tools/makefiles/simulators/Makefile.verilator

SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= uart_rx
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

.PHONY: uart_rx uart_tx waves

uart_rx: export COMPILE_ARGS := $(COMPILE_ARGS) -GCLK_RATE=50000000 -GBAUD_RATE=115200
uart_rx:
	$(MAKE) DUT=uart_rx

uart_tx: export COMPILE_ARGS := $(COMPILE_ARGS) -GCLK_RATE=50000000 -GBAUD_RATE=115200
uart_tx:
	$(MAKE) DUT=uart_tx

waves:
	@test -f dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
