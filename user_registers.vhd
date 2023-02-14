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
			i_data : in std_logic_vector(7 downto 0);
			i_we : in std_ulogic;
			o_data : out std_logic_vector(7 downto 0);

			--to/from 1-wire interface
			i_no_slave_detected : in std_ulogic;
			i_single_wire_busy : in std_ulogic;
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

	--manage the content of the control register
	manage_control_reg : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_control_register <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(i_we = '1') then
				if(unsigned(i_addr) = 0) then
					w_control_register <= i_data;
				elsif(w_single_wire_busy_rr = '1') then
					w_control_register(2 downto 0) <= (others => '0');
				end if;
			end if;
		end if;
	end process; -- manage_control_reg

	--generate the required flag signals for the 1-wire protocol 
	o_init_start <= w_control_register(0); 
	o_write_en <= w_control_register(1);
	o_read_en <= w_control_register(2);

	--manage the content of the write data register
	manage_wdata_reg : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_wdata_register <= (others => '0');
		elsif (rising_edge(i_clk)) then

			if(i_we = '1' and unsigned(i_addr) = 4) then
				o_clk_div <= i_data;
			end if;

			if(i_we = '1' and unsigned(i_addr) = 1) then
				w_wdata_register <= i_data;
			end if;
		end if;
	end process; -- manage_wdata_reg

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

	--manage the output data on the processor interface
	maanage_proc_o_data : process(all) is
	begin
		case i_addr is 
			when "000" => o_data <= w_control_register;
			when "001" => o_data <= w_wdata_register;
			when "010" => o_data <= w_status_register;
			when "011" => o_data <= i_1wire_data;
			when "100" => o_data <= o_clk_div;
			when others => o_data <= (others => '0');
		end case;
	end process; -- maanage_proc_o_data
end rtl;