`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:04:32 08/04/2010 
// Design Name: 
// Module Name:    usb_epp 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module usb_epp
  #(
	parameter C_NUM_USER_REGS  = 256
	)
	
	(			
    // bus protocol ports
		input Bus2IP_Clk,
      input Bus2IP_Reset,
		input Reset, 
                   
	   // processor side ports
		// RAM read and write ports
		input [7:0] RAM_Addr, 
		input [7:0] DIN,        
		input WRE_Data,       
		input EN_Mem,          
		input Sel_Ext_Addr,
	   output reg[7:0] address_reg,
		output update_current_address,
		output reg [7:0] DOUT,

		// control signals from the processor side
		input Bypass_ISR_Write,
		input Bypass_ISR_Read,
		//status signals
		output IRQ_EPP,
		output Read_Requested,
		output Write_Performed,
		output EPP_Performing,
		
		//		EPP side ports		
		input IFCLK,					
		input EPP_write,
		input ASTB,
		input DSTB,
		input EPPRST,
		output int_usb,
		input [7:0] DB_I,
		output [7:0] DB_O,
		output [7:0] DB_T,
		output busy
);

/************************************************************************************************************************
										state machine definition
************************************************************************************************************************/

localparam [13:0] Idle 					  	= {4'b0000 , 4'b0001 , 4'b0000 , 2'b00 }; // do nothing
localparam [13:0] RnW_Addr 				= {4'b0001 , 4'b1001 , 4'b0000 , 2'b00 }; // enter into an addrees read or write cycle
localparam [13:0] RnW_Data 				= {4'b1000 , 4'b1001 , 4'b0000 , 2'b00 }; // enter into a data read or write cycle
localparam [13:0] Read_Addr				= {4'b0011 , 4'b1001 , 4'b0100 , 2'b00 }; // read the address from the epp
localparam [13:0] Wait_on_Astb_Write	= {4'b0111 , 4'b1001 , 4'b0000 , 2'b01 }; // wait until ASTB is reasserted in a write cycle
localparam [13:0] Send_Addr				= {4'b0101 , 4'b1000 , 4'b1000 , 2'b00 }; // send the address register content to the data bus
localparam [13:0] Wait_on_Astb_Read 	= {4'b1101 , 4'b1000 , 4'b1000 , 2'b01 }; // wait until ASTB is reasserted in a read cycle
localparam [13:0] Read_Data 			   = {4'b1100 , 4'b1011 , 4'b0011 , 2'b00 }; // read the data from the EPP
localparam [13:0] Wait_on_Isr_Write	   = {4'b1110 , 4'b1011 , 4'b0000 , 2'b10 }; // wait until the PLB bus is servicing the interrupt 
																							//generated by the EPP_USB interface on a write cycle
localparam [13:0] Wait_on_Dstb_Write	= {4'b0110 , 4'b1001 , 4'b0000 , 2'b01 }; // wait until DSTB is reasserted in a write cycle
localparam [13:0] Wait_on_Isr_Read	   = {4'b1010 , 4'b1101 , 4'b0000 , 2'b10 }; // wait until the PLB bus is servicing the interrupt
																						  // generated by the EPP_USB interface on a read cycle
localparam [13:0] Send_Data 			   = {4'b1011 , 4'b1100 , 4'b0010 , 2'b00 }; // send the data register content to the data bus
localparam [13:0] Wait_on_Dstb_Read	   = {4'b1111 , 4'b1000 , 4'b0000 , 2'b01 }; // wait until DSTB is reasserted in a read cycle
localparam [13:0] Done					   = {4'b0100 , 4'b0001 , 4'b0000 , 2'b00 }; // EPP transaction cycle done


// current state & next state declaration
(* FSM_ENCODING="USER", SAFE_IMPLEMENTATION="YES", SAFE_RECOVERY_STATE="Idle" *) 
reg [13:0] StC;	
reg [13:0] StN;													  

// memory size
localparam Memsize = C_NUM_USER_REGS;

// RAM memory declaration
 (* RAM_STYLE="BLOCK" *)
reg[7:0] user_data_regs_RAM[Memsize-1:0];

//user data register to write to RAM
reg [7:0] user_write_RAM_reg ;
 
 //user data register to read from
reg [7:0] user_read_RAM_reg ;

//RAM write enable signal from the state machine
wire EPP_Mem_WE ;

//enable to read from the data bus
wire En_EPP_Mem ;

// enable to update the address register
wire Update_Addr_Reg ;

//enable to send the content of the address register instead of data register
wire EN_ADDR_OUT ;

//set DB to either output (active low) or input (active high)
wire db_t_signal ; 


//synchronize the ASTB, DSTB and EPP_WRITE_REG signals
reg  ASTB_REG ;
reg  DSTB_REG ;
reg  EPP_WRITE_REG ;

// Select processor-side dual-port memory address either from the
// external address bus or the current addres set by the EPP interface
wire [7:0] select_addr;

// one shot circuit to synchronize memory read and write signals
// from Bus2IP_Clk to IFCLK
reg [2:0] one_shot_circ_write;
reg [2:0] one_shot_circ_read;

// generate 1 as input for one-shot circuit, when memory read and/or write
// signals from the bus side are active
reg one_shot_input_write;
reg one_shot_input_read;
wire one_shot_input_read_reset;
wire one_shot_input_write_reset;
wire outputW;
wire outputR;

// One-shot outputs synchronous to IFCLK
wire Proc_Mem_W_Perf_Current_Addr;
wire Proc_Mem_R_Perf_Current_Addr;

// one-shot circuit to synchronize update_current_address to Bus2IP_Clk
reg [2:0] one_shot_update_address;
reg one_shot_set_update_address;

//assign the control signals coming from the state machine
	assign busy = StC[0];
	assign IRQ_EPP = StC[1];
	assign EPP_Mem_WE = StC[2];
	assign En_EPP_Mem = StC[3];
	assign Update_Addr_Reg = StC[4];
	assign EN_ADDR_OUT = StC[5];
	assign db_t_signal = StC[6];
	assign Write_Performed  = StC[7];
	assign Read_Requested = StC[8];
	assign EPP_Performing =  StC[9];


/******************************************************************************
		register the ASTB and DSTB signals
******************************************************************************/

always @ (posedge IFCLK)
	begin
		ASTB_REG <=  ASTB;
      DSTB_REG <=  DSTB;
      EPP_WRITE_REG <=  EPP_write;
	end
	
/******************************************************************************
		state machine registerred process 
*******************************************************************************/

always @ (posedge IFCLK)
	if (Bus2IP_Reset || (~EPPRST) || Reset)  
			StC <= Idle; 
	else
			StC <= StN;
			
/******************************************************************************
		state machine transitions 
*******************************************************************************/

always @ * 
		begin
         StN <= StC;
         case (StC)
            Idle : 							if (~ASTB_REG)
														StN <= RnW_Addr;
													else if (~DSTB_REG)
														StN <= RnW_Data;                       
						 
						 
            RnW_Addr : 						if (EPP_WRITE_REG == 0)
														StN <= Read_Addr;
													else 
														StN <= Send_Addr;                  
																					
            RnW_Data : 						if (EPP_WRITE_REG == 0)
														StN <= Read_Data;
													else
														StN <= Wait_on_Isr_Read;
							  	                            
            Read_Addr :					   StN <= Wait_on_Astb_Write;
								            
            Wait_on_Astb_Write : 		if (ASTB_REG == 1'b1)
														StN <= Done;
              
            Send_Addr : 				   StN <= Wait_on_Astb_Read;
								
								
            Wait_on_Astb_Read :        if (ASTB_REG == 1'b1)
														StN <= Done;
										 										  
            Read_Data :                StN <= Wait_on_Isr_Write;
                        
				Wait_on_Isr_Write	:			if (Bypass_ISR_Read || Proc_Mem_R_Perf_Current_Addr)
														StN <= Wait_on_Dstb_Write;
										 										  
            Wait_on_Dstb_Write :       if (DSTB_REG == 1'b1)
														StN <= Done;
																					
            Wait_on_Isr_Read : 			if (Bypass_ISR_Write || Proc_Mem_W_Perf_Current_Addr )
														StN <= Send_Data;
																				 
            Send_Data :                StN <= Wait_on_Dstb_Read;
																
            Wait_on_Dstb_Read :        if (DSTB_REG == 1'b1)
														StN <= Done;
										 										  
            Done : 		               StN <= Idle;
						                      
            default :  						StN <= Idle; // Fault Recovery                     
         endcase
		end

/***********************************************************************************************
	Assign adressses
************************************************************************************************/

always @ ( posedge IFCLK)
		if ( Update_Addr_Reg)
			address_reg <= DB_I;

assign select_addr = (Sel_Ext_Addr) ? RAM_Addr : address_reg;

/***********************************************************************************************
	RAM read and write processes
************************************************************************************************/
		// processor side read and/or write cycle into dual port RAM
		always @(posedge Bus2IP_Clk)
	  if (EN_Mem) begin  
      if (WRE_Data)
		   user_data_regs_RAM[select_addr] <= DIN;
		else
         DOUT <= user_data_regs_RAM[select_addr];
      end

		// epp side read and/or write cycle into dual port ram
   always @(posedge IFCLK)	
		if ( En_EPP_Mem ) begin 
			if (EPP_Mem_WE) 
				user_data_regs_RAM[address_reg] <= DB_I;
			else
				user_read_RAM_reg <=  user_data_regs_RAM[address_reg];
		end
		
						
/************************************************************************************************
	assign EPP output data
************************************************************************************************/
assign DB_O = (EN_ADDR_OUT) ? address_reg  : user_read_RAM_reg ;  
assign DB_T = (db_t_signal) ? 8'hFF : 8'h00;
	
/***************************************************************************************************
	one shot circuit for Memory_Read_Performed_From_Current_Address_by_the_processor
****************************************************************************************************/
assign one_shot_input_read_reset = Bus2IP_Reset || Proc_Mem_R_Perf_Current_Addr;
	
	always @ ( posedge Bus2IP_Clk or posedge one_shot_input_read_reset)
		if ( one_shot_input_read_reset ) 
				one_shot_input_read <= 1'b0;
		else if ( EN_Mem && (~(Sel_Ext_Addr)) && (~(WRE_Data)))
				one_shot_input_read <= 1'b1;
				
		assign outputR = one_shot_input_read;
				
	always @ (posedge IFCLK)
		if ( Bus2IP_Reset || (~EPPRST) || Reset  )
			  one_shot_circ_read <= 3'b000;
		else 
			  one_shot_circ_read <= {one_shot_circ_read[1:0], outputR };
			
		assign Proc_Mem_R_Perf_Current_Addr = one_shot_circ_read[0] & one_shot_circ_read[1] & (!(one_shot_circ_read[2]));
		
		
/************************************************************************************************************
		one shot circuit for Memory_Write_Performed_To_Current_Address by the processor
***************************************************************************************************************/

assign one_shot_input_write_reset = Bus2IP_Reset || Proc_Mem_W_Perf_Current_Addr ;

always @ ( posedge Bus2IP_Clk or posedge one_shot_input_write_reset)
		if ( one_shot_input_write_reset ) 
				one_shot_input_write <= 1'b0;
		else if ( EN_Mem && (~(Sel_Ext_Addr)) && WRE_Data)
				one_shot_input_write <= 1'b1;
				
		assign outputW = one_shot_input_write;
				
	always @ (posedge IFCLK)
		if ( Bus2IP_Reset || (~EPPRST) || Reset )
			  one_shot_circ_write <= 3'b000;
		else 
			  one_shot_circ_write <= {one_shot_circ_write[1:0], outputW };
			
		assign Proc_Mem_W_Perf_Current_Addr = one_shot_circ_write[0] & one_shot_circ_write[1] & (!(one_shot_circ_write[2]));
		
/************************************************************************************************************
		one shot circuit for update_current_address
***************************************************************************************************************/

always @ (posedge IFCLK or posedge update_current_address )
		if ( update_current_address )
			one_shot_set_update_address <= 1'b0;
      else if ((~EPPRST) || Reset)
         one_shot_set_update_address <= 1'b0;
		else if (Update_Addr_Reg)
			one_shot_set_update_address <= 1'b1;

always @ ( posedge Bus2IP_Clk )
		if (Bus2IP_Reset || Reset)
			one_shot_update_address <= 3'b000;
		else
			one_shot_update_address <= {one_shot_update_address[1:0], one_shot_set_update_address};

	assign update_current_address = one_shot_update_address[0] & one_shot_update_address [1] & (~(one_shot_update_address[2]));

assign int_usb = 0;

endmodule
