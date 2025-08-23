# Serial

Hardware blocks for decoding/encoding a custom reliable serial protocol.
Along with various tools/scripts to facilitate their use.

Primarily used over ethernet links to read/write test data onto FPGA based accelerator designs. See `Ethernet` directory for Ethernet related RTL.

Using the provided `avi_over_ethernet` module (TODO), this custom serial protocol can be used to access any device on the system AXI bus.
This lets you (for example) write test data to DRAM and/or access bits in CSRs via a python script running on your computer.