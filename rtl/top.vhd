library ieee;
use ieee.std_logic_1164.all;

entity top is
	port (
		--system clock and reset
		i_clk : in std_ulogic;
		i_arstn : in std_ulogic;

		--processor interface (wishbone B4 pipelined handshake interface)
		i_we : in std_ulogic;
		i_stb : in std_ulogic;
		i_addr : in std_ulogic_vector(2 downto 0);
		i_data : in std_ulogic_vector(7 downto 0);
		o_data : out std_ulogic_vector(7 downto 0);
		o_ack : out std_ulogic;
		--o_stall : out std_ulogic;

		--aditional information signals
		o_busy : out std_ulogic;
		o_transfer_w_busy : out std_ulogic;
		o_transfer_r_busy : out std_ulogic;

		--single wire interface
		--io_dq : inout std_ulogic);
		o_dq_master : out std_ulogic;
		o_dq_slave : out std_ulogic);
end top;

architecture rtl of top is
	signal w_1MHz_clk : std_ulogic;
	signal w_dq_master, w_dq_slave : std_ulogic;
begin
	single_wire_top : entity work.single_wire_top(rtl)
	port map(
		--system clock and reset
		i_clk =>i_clk,
		i_arstn =>i_arstn,

		--processor interface
		i_we =>i_we,
		i_stb => i_stb,
		i_addr =>i_addr,
		i_data =>i_data,
		o_ack => o_ack,
		o_data =>o_data,
		o_busy =>o_busy,
		o_1MHz_clk => w_1MHz_clk,
		o_transfer_w_busy =>o_transfer_w_busy,
		o_transfer_r_busy =>o_transfer_r_busy,

		--single wire interface
		--io_dq => io_dq);
		i_dq =>w_dq_slave,
		o_dq => w_dq_master);

	o_dq_master <= w_dq_master;

	single_wire_slave : entity work.single_wire_slave(rtl)
	port map(
		i_clk => w_1MHz_clk,
		--io_dq => io_dq);
		i_dq =>w_dq_master,
		o_dq => w_dq_slave);

	o_dq_slave <= w_dq_slave;
end rtl;