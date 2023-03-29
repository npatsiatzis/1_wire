--1-Wire is a voltage-based protocol for half-duplex bidirectional communication. There is always
--one master that initiates all the activity on the bus.

library ieee;
use ieee.std_logic_1164.all;

entity single_wire_top is
	port (
			--system clock and reset
			i_clk : in std_ulogic;
			i_arstn : in std_ulogic;

			--processor interface
			i_we : in std_ulogic;
			i_addr : in std_logic_vector(2 downto 0);
			i_data : in std_logic_vector(7 downto 0);
			o_1MHz_clk : out std_ulogic;
			o_data : out std_logic_vector(7 downto 0);


			--single wire interface
			--io_dq : inout std_ulogic);
			i_dq : in std_ulogic;
			o_dq : out std_ulogic);
end single_wire_top;

architecture rtl of single_wire_top is
	signal w_div_clk : std_ulogic;
	signal w_clk_div : std_ulogic_vector(7 downto 0);
	signal w_regs_o_data : std_ulogic_vector(7 downto 0);
	signal w_init_start, w_write_en, w_read_en : std_ulogic;
	signal w_busy, w_no_slave_detected : std_ulogic;
	signal w_1wire_data : std_ulogic_vector(7 downto 0);
begin 

	o_1MHz_clk <= w_div_clk;

	clock_divider : entity work.clock_divider(rtl)
	port map(
		i_clk =>i_clk,
		i_arstn =>i_arstn,
		i_clk_div =>w_clk_div,
		o_div_clk =>w_div_clk);

	user_registers : entity work.user_registers(rtl)
	port map(

		--system clock and reset
		i_clk =>i_clk,
		i_arstn =>i_arstn,

		--processor interface
		i_addr =>i_addr,
		i_data =>i_data,
		i_we =>i_we,
		o_data =>o_data,

		--to/from 1-wire interface
		i_no_slave_detected =>w_no_slave_detected,
		i_single_wire_busy =>w_busy,
		i_1wire_data =>w_1wire_data,

		o_init_start =>w_init_start,
		o_write_en =>w_write_en,
		o_read_en =>w_read_en,
		o_1wire_data =>w_regs_o_data,
		o_clk_div => w_clk_div);

	single_wire : entity work.single_wire(rtl)
	port map(
		--system reset
		i_arstn =>i_arstn,

		--user register interface 
		i_clk =>w_div_clk,								
		i_init_start =>w_init_start,
		i_write_en =>w_write_en,
		i_read_en =>w_read_en,
		i_data =>w_regs_o_data,
		i_clk_div =>w_clk_div,

		--io_dq =>io_dq,
		i_dq => i_dq,
		o_dq => o_dq,
		o_single_wire_busy =>w_busy,
		o_no_slave_detected =>w_no_slave_detected,
		o_data =>w_1wire_data);
end rtl;