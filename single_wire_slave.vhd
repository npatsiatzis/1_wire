-- very simple 1-wire slave model based on the ds18s20. only the 
-- very basic read/write functionalities are implemented

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_wire_slave is
	port (
			i_clk : in std_ulogic; 		-- 1MHz clk (mimicking the 1us internal strobes of the device)
			--io_dq : inout std_ulogic);
			i_dq : in std_ulogic;
			o_dq : out std_ulogic);
end single_wire_slave;

architecture rtl of single_wire_slave is 
	constant WAIT_AFTER_RESET_VALUE : natural := 30;
	constant PRESENCE_PULSE_VALUE : natural := 120;
	--when to sample the bus after the master initiates the write time slot
	constant SAMPLE_BUS_VALUE : natural := 30;
	--when to write bus after the master initiates the read time slot			
	constant WRITE_BUS_VALUE : natural := 5;  		
	constant WRITE_SLOT_VALUE : natural := 60;

	type t_reset_presence_state is (reset_presence_idle, reset_detected,presence_pulse,release_bus);
	signal w_reset_presence_state : t_reset_presence_state;
	-- master TX slave RX
	type t_read_state is (read_idle, wait_to_sample_bus,sample_bus,update_scratchpad);
	signal w_read_state : t_read_state;
	--master RX slave TX
	type t_write_state is (write_idle,wait_to_drive_bus, drive_bus);
	signal w_write_state : t_write_state;

	signal w_dq_r : std_ulogic := '1';

	signal w_cnt_reset_presence : unsigned(6 downto 0) :=(others => '0');
	signal w_reset_presence_done : std_ulogic := '0';
	signal w_cnt_read  : unsigned(6 downto 0) :=(others => '0');
	signal w_cnt_write : unsigned(6 downto 0) :=(others => '0');
	signal w_dq_word_read : std_logic_vector(7 downto 0);
	signal w_scratchpad : std_logic_vector(7 downto 0);
	signal w_scratchpad_r : std_logic_vector(7 downto 0);
	signal index_write : integer range 0 to 7;
begin
	reset_presence : process(i_clk) is
	begin
		if(rising_edge(i_clk)) then
			w_dq_r <= i_dq;
			w_cnt_reset_presence <= w_cnt_reset_presence +1;
			case w_reset_presence_state is 
				when reset_presence_idle =>
					if(i_dq = '1' and w_dq_r = '0' and w_reset_presence_done = '0') then
						w_reset_presence_state <= reset_detected;
						w_cnt_reset_presence <= (others => '0');
					end if;
				when reset_detected =>
					if(w_cnt_reset_presence > WAIT_AFTER_RESET_VALUE) then
						w_reset_presence_state <= presence_pulse;
						w_cnt_reset_presence <= (others => '0');
					end if;
				when presence_pulse =>
					--o_dq <= '0';
					if(w_cnt_reset_presence >= PRESENCE_PULSE_VALUE) then
						w_reset_presence_state <= release_bus;
					end if;

					--release dq;
					--disable this fsm with flag set to 1 and clared?

				when release_bus =>
					--o_dq <= 'Z';
					w_reset_presence_state <= reset_presence_idle;
					w_reset_presence_done <= '1';
				when others =>
					--o_dq <= 'Z';
					w_reset_presence_state <= reset_presence_idle;
			end case;
		end if;
	end process; -- reset_presence

	read_FSM : process(i_clk) is
		variable v_index_read : integer range 0 to 8 := 0;
	begin
		if(rising_edge(i_clk)) then
			w_cnt_read <= w_cnt_read +1;
			case w_read_state is 
				when read_idle =>
					if(w_reset_presence_done = '1' and i_dq = '0' and w_dq_r = '1' and w_scratchpad /= "10111110") then
					--if(w_reset_presence_state = '1' and io_dq = '0' and w_dq_r = '1' and w_scratchpad_r = "01001110") then
						w_read_state <= wait_to_sample_bus;
						w_cnt_read <= (others => '0');
					end if;
				when wait_to_sample_bus =>
					if(w_cnt_read >= SAMPLE_BUS_VALUE) then
						w_read_state <= sample_bus;
					end if;
				when sample_bus =>
					w_dq_word_read(v_index_read) <= i_dq;
					w_read_state <= update_scratchpad;
					if(v_index_read <8) then
						v_index_read := v_index_read +1;
					else
						v_index_read := 0;
					end if;
				when update_scratchpad =>
					if(v_index_read = 8) then
						w_scratchpad <= w_dq_word_read;
						w_scratchpad_r <= w_scratchpad;
						v_index_read := 0;
					end if;
					w_read_state <= read_idle;
				end case;
		end if;
	end process; -- read_FSM

	write_FSM : process(i_clk) is
		--variable v_index_write : integer range 0 to 7 :=0;
	begin
		if(rising_edge(i_clk)) then 
			w_cnt_write <= w_cnt_write +1;
			case w_write_state is 
				when write_idle =>
					if(w_reset_presence_done = '1' and i_dq = '0' and w_dq_r = '1' and w_scratchpad = "10111110") then
						w_write_state <= wait_to_drive_bus;
						w_cnt_write <= (others => '0');
					end if;
				when wait_to_drive_bus =>
					if(w_cnt_write >= WRITE_BUS_VALUE) then
						w_write_state <= drive_bus;
					end if;
				when drive_bus =>
					--o_dq <= w_scratchpad(v_index_write);
					if(w_cnt_write >= WRITE_SLOT_VALUE) then
						w_write_state <= write_idle;
						if(index_write < 7) then
							index_write <= index_write +1;
						else
							index_write <= 0;
						end if;
					end if;
			end case;
		end if;
	end process; -- write_FSM

	o_dq <= '0' when (w_reset_presence_state = presence_pulse) else
		 	--w_scratchpad(index_write) when (w_write_state = drive_bus) else 'Z';
		 	w_scratchpad_r(index_write) when (w_write_state = drive_bus) else '1'; --for cocotb verification purpooses
end rtl;