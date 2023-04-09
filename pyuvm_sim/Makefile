# Makefile

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
EXTRA_ARGS += --std=08
SIM_ARGS += --wave=wave.ghw

VHDL_SOURCES += $(PWD)/../rtl/toggle_synchronizer.vhd
VHDL_SOURCES += $(PWD)/../rtl/clock_divider.vhd
VHDL_SOURCES += $(PWD)/../rtl/user_registers.vhd
VHDL_SOURCES += $(PWD)/../rtl/single_wire.vhd
VHDL_SOURCES += $(PWD)/../rtl/single_wire_slave.vhd
VHDL_SOURCES += $(PWD)/../rtl/single_wire_top.vhd
VHDL_SOURCES += $(PWD)/../rtl/top.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# MODULE is the basename of the Python test file

test:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_pyuvm TOPLEVEL=top
		
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim