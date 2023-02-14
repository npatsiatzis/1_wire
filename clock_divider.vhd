-- a clock divider module is useful since all timing behavior related to
-- the initialization-presence pulses as well as the read-write time slots
-- is in us. Therefore it is useful to prescal the system clock in MHz

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
	port (
			i_clk : in std_ulogic;
			i_arstn : in std_ulogic;
			i_clk_div : in std_ulogic_vector(7 downto 0);
			o_div_clk : out std_ulogic);
end clock_divider;

architecture rtl of clock_divider is
	signal w_clk_div_cnt : unsigned(7 downto 0);
	signal w_div_clk : std_ulogic;
begin
	--generate the divided clock based on the system clock and 
	--the input clock div. value

	gen_clk_div : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_clk_div_cnt <= (others => '0');
			w_div_clk <= '0';
		elsif (rising_edge(i_clk)) then
			if(w_clk_div_cnt < unsigned(i_clk_div)) then
				w_clk_div_cnt <= w_clk_div_cnt+1;
			else
				w_clk_div_cnt <= (others => '0');
				w_div_clk <= not (w_div_clk);
			end if;
		end if;
	end process; -- gen_clk_div

	o_div_clk <= w_div_clk;
end rtl;