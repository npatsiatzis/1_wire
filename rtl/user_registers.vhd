library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity user_registers is
	port (
			--system clock and reset
			i_clk : in std_ulogic;
			i_arstn : in std_ulogic;

			--processor interface
			i_addr : in std_logic_vector(2 downto 0);
			i_we : in std_ulogic;
			i_stb : in std_ulogic;
			i_data : in std_logic_vector(7 downto 0);
			o_ack : out std_ulogic;
			o_data : out std_logic_vector(7 downto 0);

			--to/from 1-wire interface
			i_no_slave_detected : in std_ulogic;
			i_single_wire_busy : in std_ulogic;
			i_wr_termination : in std_ulogic;
			i_rd_termination : in std_ulogic;
			i_1wire_data : in std_logic_vector(7 downto 0);

			o_init_start : out std_ulogic;
			o_write_en : out std_ulogic;
			o_read_en : out std_ulogic;
			o_1wire_data : out std_logic_vector(7 downto 0);
			o_clk_div : out std_ulogic_vector(7 downto 0));
end user_registers;

architecture rtl of user_registers is
	signal w_single_wire_busy_r, w_single_wire_busy_rr : std_ulogic;
	signal w_control_register : std_logic_vector(7 downto 0);
	signal w_wdata_register : std_logic_vector(7 downto 0);
	signal w_status_register : std_logic_vector(7 downto 0);

	signal w_ack : std_ulogic;
	signal w_wr_termination_r , w_rd_termination_r : std_ulogic;

begin

	register_transfer_proc_busy : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_single_wire_busy_r <= '0';
			w_single_wire_busy_rr <= '0';
		elsif (rising_edge(i_clk)) then
			w_single_wire_busy_r <= i_single_wire_busy;
			w_single_wire_busy_rr <= w_single_wire_busy_r;
		end if;
	end process; -- register_transfer_proc_busy

	--generate the required flag signals for the 1-wire protocol 
	o_read_en <= w_control_register(2);
	o_write_en <= w_control_register(1);
	o_init_start <= w_control_register(0); 

	--manage the content of the control register and the write data register
	manage_control_data_reg : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_control_register <= (others => '0');
			w_wdata_register <= (others => '0');
			w_ack <= '0';
		elsif (rising_edge(i_clk)) then
			w_ack <= '0';

			if(i_stb = '1' and i_we = '1') then
				if(unsigned(i_addr) = 0) then
					w_control_register <= i_data;
					w_ack <= '1';
				elsif(w_single_wire_busy_rr = '1') then
					w_control_register(2 downto 0) <= (others => '0');
				end if;

				if(unsigned(i_addr) = 4) then
					o_clk_div <= i_data;
					w_ack <= '1';
				end if;

				if(unsigned(i_addr) = 1) then
					w_wdata_register <= i_data;
					w_ack <= '1';
				end if;
			end if;
		end if;
	end process; -- manage_control_data_reg

	o_1wire_data <= w_wdata_register;

	--manage the contents of the status register
	identifier : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_status_register <= (others => '0');
		elsif (rising_edge(i_clk)) then
			w_status_register <= "000" & w_single_wire_busy_rr & i_no_slave_detected & o_read_en & o_write_en & o_init_start;
		end if;
	end process; -- identifier

	gen_ack : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_ack <= '0';
			w_wr_termination_r <= '0';
			w_rd_termination_r <= '0';
		elsif (rising_edge(i_clk)) then
			w_wr_termination_r <= i_wr_termination;
			w_rd_termination_r <= i_rd_termination;

			if(i_wr_termination = '0' and w_wr_termination_r = '1') then
				o_ack <= '1';
			elsif(i_rd_termination = '0' and w_rd_termination_r = '1') then
				o_ack <= '1';
				o_data <= i_1wire_data;
			else
				o_ack <= w_ack;
			end if;
		end if;
	end process; -- gen_ack

end rtl;