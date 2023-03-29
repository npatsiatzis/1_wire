--1-Wire master that initiates all activity taking place in the bus.
--Each transaction consists of a reset pulse, followed by an 8-bit command
--followed by data being sent or received in groups of 8 bits.
--The 4 basic operations of a 1-Wire master are "Reset", "Write 0 bit", "Write 1 bit" and "Read bit"

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_wire is
	port (
			--system reset
			i_sys_clk : in std_ulogic;
			i_arstn : in std_ulogic;

			--user register interface 
			i_clk : in std_ulogic;			--divided protocol clock
			i_init_start : out std_ulogic;
			i_write_en : out std_ulogic;
			i_read_en : out std_ulogic;
			i_data : in std_logic_vector(7 downto 0);
			i_clk_div : out std_ulogic_vector(7 downto 0);

			--io_dq : inout std_ulogic;
			i_dq : in std_ulogic;
			o_dq : out std_ulogic; 
			o_single_wire_busy : out std_ulogic;
			o_transfer_w_busy : out std_ulogic;
			o_transfer_r_busy : out std_ulogic;
			o_no_slave_detected : out std_ulogic;
			o_data : out std_ulogic_vector(7 downto 0));
end single_wire;

architecture rtl of single_wire is
	--timing constants for the initialization procedure
	constant RESET_RELEASE : natural := 480;
	constant PRESENCE_WAIT_SLAVE : natural := 495;
	constant PRESENCE_LOW : natural := 555;
	constant INIT_TIME_SLOT : natural := 960;

	--timing constants for the data transfer procedure 
	constant WRITE_ONE_LOW_LEVEL : natural := 6;
	constant WRITE_DATA_TIME_SLOT : natural := 60;
	constant DATA_TX_END : natural := 70;
	constant READ_DATA_LOW_LEVEL : natural := 1;
	constant READ_DATA_SAMPLE : natural := 15;
	constant READ_DATA_TIME_SLOT : natural := 60;
	constant DATA_RX_END : natural := 70;

	type t_init_state is (INIT_IDLE,SEND_RESET,PRESENCE_WAIT,PRESENCE_DETECT,PRESENCE_RELEASE,INIT_END,INIT_TURN_AROUND);
	signal w_init_state, w_init_state_r : t_init_state;
	type t_transfer_state is (TRANSFER_IDLE,WRITE_START,WRITE_BIT,READ_START,READ_BIT,READ_BIT_END,WRITE_RECOVERY_END, READ_RECOVERY_END,DATA_TURN_AROUND);
	signal w_transfer_state : t_transfer_state;

	signal w_init_start_r,w_init_start_rr, w_write_en_r, w_write_en_rr, w_read_en_r, w_read_en_rr : std_ulogic;

	signal w_init_time_cnt : unsigned(9 downto 0);
	signal w_init_proc_busy : std_ulogic;

	signal w_transfer_time_cnt : unsigned(6 downto 0);
	signal w_transfer_proc_busy : std_ulogic;
	signal w_transfer_w_busy : std_ulogic;
	signal w_transfer_r_busy : std_ulogic;
	signal w_transfer_cnt_rst : std_ulogic;
	signal w_index : integer range 0 to 8;
	signal w_dq_en_n : std_ulogic;

	signal f_is_data_tx : std_ulogic;
begin

	--synchronize the init/read/write signals that are generated in the system clock domain
	--by the user register module, in the current working domain


	toggle_sync_init : entity work.toggle_synchronizer(arch)
	generic map(
			g_stages => 2)
	port map(
			--domain A bus
			i_clk_A =>i_sys_clk,
			i_rst_A =>i_arstn,
			i_pulse_A =>i_init_start,

			--domain B bus
			i_clk_B =>i_sys_clk,
			i_rst_B =>i_arstn,
			o_pulse_B => w_init_start_rr);

	toggle_sync_w : entity work.toggle_synchronizer(arch)
	generic map(
			g_stages => 2)
	port map(
			--domain A bus
			i_clk_A =>i_sys_clk,
			i_rst_A =>i_arstn,
			i_pulse_A =>i_write_en,

			--domain B bus
			i_clk_B =>i_sys_clk,
			i_rst_B =>i_arstn,
			o_pulse_B => w_write_en_rr);

	toggle_sync_r : entity work.toggle_synchronizer(arch)
	generic map(
			g_stages => 2)
	port map(
			--domain A bus
			i_clk_A =>i_sys_clk,
			i_rst_A =>i_arstn,
			i_pulse_A =>i_read_en,

			--domain B bus
			i_clk_B =>i_sys_clk,
			i_rst_B =>i_arstn,
			o_pulse_B => w_read_en_rr);

	--manage init FSM time counter

	gen_init_cnt : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_init_time_cnt <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(w_init_state = INIT_TURN_AROUND or w_init_state = INIT_IDLE) then
				w_init_time_cnt <= (others => '0');
			else
				w_init_time_cnt <= w_init_time_cnt +1;
			end if;
		end if;
	end process; -- gen_init_cnt

	--initialization procedure FSM
	--performs 1 of the 4 basic operations, namely "Reset"
	--"Reset" operation resets the 1-Wire slave devices and 
	--makes them get ready to receive a command

    -- implementation of "Reset" operation
    --	      	1    |	 2 		|     3    | 	4 	|
    --        _______			 _____	    _________
    -- 1Wire         \__________/  	  \____/
    --         	        reset     presence   presence
    -- 			       release     detect    release
    --			    <----------><---------><-------->	 		

	init_FSM : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_init_state <= INIT_IDLE;
		elsif (rising_edge(i_clk)) then
			w_init_state_r <= w_init_state;
			case w_init_state is 
				when INIT_IDLE =>
					if(w_init_start_rr = '1') then
						w_init_state <= SEND_RESET;
					end if;
				when SEND_RESET =>
					if(w_init_time_cnt >= RESET_RELEASE) then
						w_init_state <= PRESENCE_WAIT;
					end if;
				when PRESENCE_WAIT =>
					if(w_init_time_cnt >= PRESENCE_WAIT_SLAVE) then
						w_init_state <= PRESENCE_DETECT;
					end if;
				when PRESENCE_DETECT =>
					if(i_dq = '0') then
						w_init_state <= PRESENCE_RELEASE;
					elsif(w_init_time_cnt >= INIT_TIME_SLOT) then
						w_init_state <= INIT_TURN_AROUND;
					end if;
				when PRESENCE_RELEASE =>
					if(w_init_time_cnt >= PRESENCE_LOW) then
						w_init_state <= INIT_END;
					end if;
				when INIT_END => 
					if(w_init_time_cnt >= INIT_TIME_SLOT) then
						w_init_state <= INIT_TURN_AROUND;
					end if;
				when INIT_TURN_AROUND =>
					w_init_state <= INIT_IDLE;
				when others =>
					w_init_state <= INIT_IDLE;
			end case;
		end if;
	end process; -- init_FSM

	--data transfer procedure FSM

	--initialization procedure in progress indicator

	init_busy : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_init_proc_busy <= '0';
		elsif (rising_edge (i_clk))	then

			if(w_init_start_rr = '1') then
				w_init_proc_busy <= '1';
			elsif (w_init_state = INIT_IDLE and w_init_state_r = INIT_TURN_AROUND) then
				w_init_proc_busy <= '0';
			end if;
		end if;
	end process; -- init_busy

	--generate the no slave device detected indicator

	gen_no_slave_detected : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_no_slave_detected <= '0';
		elsif (rising_edge(i_clk)) then
			if(w_init_state = INIT_TURN_AROUND and  w_init_state_r = PRESENCE_DETECT) then
				o_no_slave_detected <= '1';
			elsif (w_init_state = PRESENCE_RELEASE and w_init_state_r = PRESENCE_DETECT) then
				o_no_slave_detected <= '0';
			end if;
		end if;
	end process; -- gen_no_slave_detected

	--manage data transfer FSM time counter

	gen_transfer_time_cnt : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_transfer_time_cnt <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(w_transfer_state = TRANSFER_IDLE or w_transfer_cnt_rst = '1') then
				w_transfer_time_cnt <= (others => '0');
			else
				w_transfer_time_cnt <= w_transfer_time_cnt +1;
			end if;
		end if;
	end process; -- gen_transfer_time_cnt

	--data transfer procedure in progress indicator

	tranfer_busy : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_transfer_proc_busy <= '0';
			o_transfer_w_busy <= '0';
			o_transfer_r_busy <= '0';
		elsif (rising_edge (i_clk))	then
			if(w_transfer_state = WRITE_START) then
				o_transfer_w_busy <= '1';
			elsif(w_transfer_state = READ_START) then
				o_transfer_r_busy <= '1';
			elsif(w_transfer_state = DATA_TURN_AROUND) then
				o_transfer_w_busy <= '0';
				o_transfer_r_busy <= '0';
			end if;

			if(w_write_en_rr = '1' or w_read_en_rr = '1') then
				w_transfer_proc_busy <= '1';
			elsif (w_transfer_state = DATA_TURN_AROUND) then
				w_transfer_proc_busy <= '0';
			end if;
		end if;
	end process; -- tranfer_busy

	o_single_wire_busy <= w_init_proc_busy or w_transfer_proc_busy;

	--data transfer bit index indicator

	gen_index_indicator : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_index <= 0;
		elsif (rising_edge(i_clk)) then
			if(w_transfer_time_cnt >= DATA_TX_END and w_index < 7) then
				w_index <= w_index +1;
			elsif (w_index >= 7 and w_transfer_time_cnt >=DATA_TX_END) then
				w_index <= 0;
			end if;
		end if;
	end process; -- gen_index_indicator

	-- reset the data transfer time counter after each bit transaction

	transfer_cnt_rst : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_transfer_cnt_rst <= '0';
		elsif (rising_edge(i_clk)) then
			if(w_transfer_state = WRITE_START or w_transfer_state = READ_START) then
				w_transfer_cnt_rst <= '0';
			elsif ((w_transfer_state = WRITE_RECOVERY_END  OR w_transfer_state = READ_RECOVERY_END) and w_transfer_time_cnt >= DATA_TX_END-1) then
				w_transfer_cnt_rst <= '1';
			elsif (w_transfer_state = TRANSFER_IDLE or w_transfer_state = DATA_TURN_AROUND) then
				w_transfer_cnt_rst <= '1';
			end if;
		end if;
	end process; -- transfer_cnt_rst

	--data transfer FSM 
	--performs 3 of the 4 basic operations, namely "Write bit 0", "Write bit 1", "Read bit"
	--"Reset" operation resets the 1-Wire slave devices and 
	--makes them get ready to receive a command

    -- implementation of "Write bit 1" operation
    --	      	1    |	 2 		|     3    		  |
    --        _______			 __________________
    -- 1Wire         \__________/  	  
    --         	        write 1  write data  data(recovery)
    -- 			       low level   slot      end
    --			    <----------><---------><-------->	

    
    -- implementation of "Write bit 0" operation
    --	      	1    |	 2 		|     3    	|	 4    |
    --        _______			 			 __________
    -- 1Wire         \______________________/
    --         	        write 1  write data  data(recovery)
    -- 			       low level   slot      end
    --			    <----------><---------><-------->	

    
    -- implementation of "Read bit" operation
    --	      	1    |	 2 		|  3  | 	4  	  |
    --        _______			 __________________
    -- 1Wire         \__________/__________/  	  
    --         	      read data   data   read data 
    -- 			       low level sample   slot end
    --			    <----------><-----><------------>	


	data_transfer_FSM : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_transfer_state <= TRANSFER_IDLE;
			f_is_data_tx<= '0';
		elsif (rising_edge(i_clk)) then
			f_is_data_tx <= '0';
			case w_transfer_state is 
				when TRANSFER_IDLE =>
					if(w_write_en_rr = '1') then
						w_transfer_state <= WRITE_START;
					elsif (w_read_en_rr = '1') then
						w_transfer_state <= READ_START;
					end if;
				when WRITE_START =>
					if(w_transfer_time_cnt >= WRITE_ONE_LOW_LEVEL) then
						w_transfer_state <= WRITE_BIT;
					end if;
				when WRITE_BIT =>
					if(w_transfer_time_cnt >= WRITE_DATA_TIME_SLOT) then
						w_transfer_state <= WRITE_RECOVERY_END;
						f_is_data_tx <= '1';
					end if;
				when WRITE_RECOVERY_END=>
					if(w_transfer_time_cnt >= DATA_TX_END and w_index < 7) then
						w_transfer_state <= WRITE_START;
					elsif w_transfer_time_cnt >= DATA_TX_END and w_index >= 7 then
						w_transfer_state <= DATA_TURN_AROUND;
					end if;
				when READ_START =>
					if(w_transfer_time_cnt >= READ_DATA_LOW_LEVEL) then
						w_transfer_state <= READ_BIT;
					end if;
				when READ_BIT =>
					if(w_transfer_time_cnt >= READ_DATA_SAMPLE) then
						w_transfer_state <= READ_BIT_END;
					end if; 
				when READ_BIT_END =>
					if(w_transfer_time_cnt >= READ_DATA_TIME_SLOT) then
						w_transfer_state <= READ_RECOVERY_END;
					end if;
				when READ_RECOVERY_END =>
					if(w_transfer_time_cnt >= DATA_RX_END and w_index < 7) then
						w_transfer_state <= READ_START;
					elsif (w_transfer_time_cnt >= DATA_RX_END and w_index >=7) then
						w_transfer_state <= DATA_TURN_AROUND;
					end if;
				when DATA_TURN_AROUND =>
					w_transfer_state <= TRANSFER_IDLE;
				when others =>
					w_transfer_state <= TRANSFER_IDLE;
			end case;
		end if;
	end process; -- data_transfer_FSM

	--generate output read data

	gen_o_data : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			o_data <= (others => '0');
		elsif (rising_edge(i_clk)) then
			if(w_transfer_state = READ_BIT and w_transfer_time_cnt = READ_DATA_SAMPLE) then
				o_data(w_index) <= i_dq;
			end if;
		end if;
	end process; -- gen_o_data

	--o_dq <= '0' when w_dq_en_n = '0' else 'Z';
	--for focotb verification purposes
	o_dq <= '0' when w_dq_en_n = '0' else '1';

	--generate the (active low) dq en signal which denotes when the
	--logic drives the dq line

	gen_dq_en : process(i_clk,i_arstn) is
	begin
		if(i_arstn = '0') then
			w_dq_en_n <= '1';
		elsif (rising_edge(i_clk)) then
			if(w_init_state = SEND_RESET or w_transfer_state = WRITE_START or 
				(w_transfer_state = WRITE_BIT and i_data(w_index) = '0') or
				 w_transfer_state = READ_START) then
				w_dq_en_n <= '0';
			else
				w_dq_en_n <= '1';
			end if;
		end if;
	end process; -- gen_dq_en
end rtl;