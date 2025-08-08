SIM ?= verilator
TOPLEVEL_LANG = verilog

DUT      ?= serial_decoder
# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = $(DUT)
# MODULE is the basename of the Python test file
MODULE   = test_$(DUT)
#VERILOG_SOURCES += ../$(DUT).sv
VERILOG_SOURCES += $(shell find .. -name "*.sv")
VERILOG_SOURCES += $(shell find ../../UART -name "*.sv")
VERILOG_SOURCES += $(shell find ../../CRC -name "*.sv")
VERILOG_SOURCES += $(shell find ../../AXI -name "*.sv")
VERILOG_SOURCES += $(shell find ../../FIFO -name "*.sv")
VERILOG_SOURCES += $(shell find ../../DMA -name "*.sv")
VERILOG_SOURCES += $(shell find ../../SDRAM -name "*.sv")

# warnings
COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
# waveforms
EXTRA_ARGS += --trace --trace-fst --trace-threads 2 --trace-structs
EXTRA_ARGS += --threads 6

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: serial_decoder waves

soc: export COMPILE_ARGS := $(COMPILE_ARGS) -GCLK_RATE=50000000 -GBAUD_RATE=115200
soc:
	$(MAKE) DUT=soc -j10

serial_decoder: export COMPILE_ARGS := $(COMPILE_ARGS) -GCLK_RATE=50000000 -GBAUD_RATE=115200
serial_decoder:
	$(MAKE) DUT=serial_decoder -j10


interface: export COMPILE_ARGS := $(COMPILE_ARGS) -GCLK_RATE=50000000 -GBAUD_RATE=115200
interface:
	$(MAKE) DUT=serial_interface -j10


waves:
	@test -f dump.fst || (echo "Error: dump.fst not found. Simulate a target first." && exit 1)
	surfer -s state.surf.ron dump.fst

clean::
	rm -rf __pycache__
	rm -f results.xml
