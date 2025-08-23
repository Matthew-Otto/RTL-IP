# 1 Gigabit Ethernet MAC / PCS

## ERATTA

Issue:
The interpacket gap calculation on the transmit interface doesn't account for 8 bits of preamble. It is possible that buffers in the PCS (sgmii_pcs.sv) could overflow

Fix:
generate the preamble (and strip the preamble for RX) in the mac instead of the PCS