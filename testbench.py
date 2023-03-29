# Functional test for uart module
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer,RisingEdge,FallingEdge,ClockCycles,ReadWrite
from cocotb.result import TestFailure
import random
from cocotb_coverage.coverage import CoverPoint,coverage_db

covered_valued = [78,190]
# data width should be in range(2**8) but it's reduced for execution time issues
data_width = 3

full = False
def notify():
	global full
	full = True


# at_least = value is superfluous, just shows how you can determine the amount of times that
# a bin must be hit to considered covered
@CoverPoint("top.i_data",xf = lambda x : x, bins = list(range(2**data_width)), at_least=1)
def number_cover(data):
	covered_valued.append(int(data))

async def reset(dut,cycles=1):
	dut.i_arstn.value = 0
	dut.i_we.value = 0
	dut.i_addr.value = 0
	dut.i_data.value = 0
	await ClockCycles(dut.i_clk,cycles)
	dut.i_arstn.value = 1
	await RisingEdge(dut.i_clk)
	dut._log.info("the core was reset")


	# 					USER REGISTER MAP

	# 			Address 		| 		Functionality
	#			   0 			|	control register (R(i_we = 0)/W(i_we = 1))
	#			   1 			|	data TX register (R/W)  (to transfer command codes / data)
	#			   2 			|	status register  (R)
	#			   3 			|	data RX register (R)	(to receive data)
	#			   4 			|	clock div. register (R/W)

@cocotb.test()
async def test(dut):
	"""Check results and coverage for single_wire controller"""

	cocotb.start_soon(Clock(dut.i_clk, 500, units="ns").start())
	await reset(dut,5)	

	

	dut.i_addr.value = 4   			# clk div register
	dut.i_we.value = 1  		    # write the register
	dut.i_data.value = 1

	await RisingEdge(dut.w_1MHz_clk)
	
	while(full != True):

		dut.i_addr.value = 0 			# control register
		dut.i_we.value = 1
		dut.i_data.value = 1  			# trigger reset pulse

		await RisingEdge(dut.w_1MHz_clk)
		dut.i_addr.value =0 
		dut.i_we.value = 1
		dut.i_data.value = 0
		await FallingEdge(dut.single_wire_top.w_busy)


		# prepare to transfer data on the 1-wire bus

		dut.i_addr.value = 1   			# data tx register
		dut.i_we.value = 1
		dut.i_data.value = 78			# write scratchpad command

		await RisingEdge(dut.w_1MHz_clk)

		dut.i_addr.value = 0  			# control register
		dut.i_we.value = 1 				
		dut.i_data.value = 2 			# reset low, write high


		await RisingEdge(dut.w_1MHz_clk)
		dut.i_addr.value =0 
		dut.i_we.value = 1
		dut.i_data.value = 0
		await FallingEdge(dut.single_wire_top.w_busy)


		# prepare to transfer data on the 1-wire bus

		dut.i_addr.value = 1   			# data tx register
		dut.i_we.value = 1
		data = random.randint(0,2**data_width-1)
		while(data in covered_valued):
			data = random.randint(0,2**data_width-1)

		dut.i_data.value = data			# data to write to scratchpad

		await RisingEdge(dut.w_1MHz_clk)

		dut.i_addr.value = 0  			# control register
		dut.i_we.value = 1 				
		dut.i_data.value = 2 			# reset low, write high


		await RisingEdge(dut.w_1MHz_clk)
		dut.i_addr.value =0 			# control register
		dut.i_we.value = 1
		dut.i_data.value = 0
		await FallingEdge(dut.single_wire_top.w_busy)


		# prepare to transfer data on the 1-wire bus

		dut.i_addr.value = 1   			# data tx register
		dut.i_we.value = 1
		dut.i_data.value = 190			# read scratchpad command

		await RisingEdge(dut.w_1MHz_clk)

		dut.i_addr.value = 0  			# control register
		dut.i_we.value = 1 				
		dut.i_data.value = 2 			# reset low, read high


		await RisingEdge(dut.w_1MHz_clk)
		dut.i_addr.value =0 			# control register
		dut.i_we.value = 1
		dut.i_data.value = 0
		await FallingEdge(dut.single_wire_top.w_busy)


		# prepare to read data on the 1-wire bus

		dut.i_addr.value = 0   			# control register
		dut.i_we.value = 1
		dut.i_data.value = 4			# read scratchpad command

		await RisingEdge(dut.w_1MHz_clk)
		dut.i_addr.value =0 			# control register
		dut.i_we.value = 1
		dut.i_data.value = 0
		await FallingEdge(dut.single_wire_top.w_busy)

		dut.i_addr.value = 3   			# rx data register
		dut.i_we.value = 0
		dut.i_data.value = 0			# read out data transfered from 1wire slave

		await RisingEdge(dut.w_1MHz_clk)

		assert not (data != int(dut.o_data.value)),"Different expected to actual read data"
		coverage_db["top.i_data"].add_threshold_callback(notify, 100)
		number_cover(data)

	# coverage_db.report_coverage(cocotb.log.info,bins=True)
	coverage_db.export_to_xml(filename="coverage.xml")


