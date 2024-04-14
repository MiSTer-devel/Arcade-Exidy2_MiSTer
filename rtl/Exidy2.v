//============================================================================
//  Arcade: Exidy Universal Game Board V2
//
//  Manufaturer: Exidy
//  Type: Arcade Game
//  Genre: Multiple
//  Orientation: Both - ROM dependant 
//
//  Hardware Description by Anton Gale
//  https://github.com/antongale/Arcade-Exidy2
//
//============================================================================
`timescale 1ns/1ps

module exidy2(
	input master_clock,
	input audio_clk,
	input [7:0] pcb,	
	input [7:0] mod_shift,
	output reg RED,    
	output reg GREEN,	 
	output reg BLUE,	 
	output core_pix_clk,			
	output H_SYNC,				
	output V_SYNC,				
	output H_BLANK,
	output V_BLANK,
	input RESET_n,				
	input pause,
	//joystick controls
	input m_right,
	input m_left,	
	input m_down,   
	input m_up,  	
	input m_fire,
	input m_yel, 	
	input m_red, 	
	input m_blu, 	
	input m_start1p,	
	input m_start2p,	
	input m_coina,  	
	input m_coinb,  	

	input [7:0] DIP1,
	input [7:0] DIP2,
	input [7:0] DIP3,	
	input [24:0] dn_addr,
	input 		 dn_wr,
	input [7:0]  dn_data,
	output signed [15:0] audio_l, 
	output signed [15:0] audio_r, 
	input [15:0] hs_address,
	output [7:0] hs_data_out,
	input [7:0] hs_data_in,
	input hs_write
);

//ROM SETS:
//Uses ROMs instead of RAM for character set - no colour
//0:     Side Trak: sidetrac

//Uses RAM for character set

//1:          Targ: targ,targc
//2:       Spectar: spectar,spectar1,spectarrf,rallys,rallysa, panzer, phantoma,phantom

//Uses audioboard with customizable palette:

//3:    Mouse Trap: mtrap,mtrap4,mtrap4g,mtrap3,mtrap2,mtrapb,mtrapb2
//4:       Venture: venture,venture5a,venture4,venture5b
//5:Teeter Torture: teetert
//6:     Pepper II: pepper2, pepper27
//7:      Hard Hat: hardhat
//8:           FAX: fax
//8:         FAX 2: fax2

//EXIDY S2 CLOCKS 
reg CLK22,CLK11;
reg BCLK,BCLKB, HCLK, CLD,BCLKX;
reg PH_1x,PH_1,PH_6,PH_6B,PH_6C,CCRY;
reg HCNT;

//clock enables
reg [6:0] cencnt =7'd0;

//master clock on the Exidy 2 is 11.289MHz : derived from 45.156MHz
//divided clocks:
//BCLK :   master_clock/2  = 5.646 MHz
//HCLK :   master_clock/4  = 2.822 MHz
//CLD  :   master_clock/8  = 2.822 MHz
//1ØO  :  !master_clock/16 =   706 kHz
//6ØO  : !!master_clock/16 =   706 kHz

always @(posedge master_clock) begin
	cencnt  <= cencnt+7'd1;
end

always @(posedge master_clock) begin
	CLK22	  	<= cencnt[0]   == 1'd0;
	CLK11	  	<= cencnt[1:0] == 2'd0;
	BCLK	  	<= cencnt[2:0] == 3'd0;
	BCLKB	  	<= cencnt[2:0] == 3'd1;	
	HCLK		<= cencnt[3:0] == 4'd0;
	CLD		<= cencnt[4:0] == 5'd0;
   PH_1		<= cencnt[5:0] == 6'd31;   
	PH_6		<= cencnt[5:0] == 6'd0;
	PH_6B		<= cencnt[5:0] == 6'd26;
	PH_6C		<= cencnt[5:0] == 6'd27;	
	HCNT		<= cencnt[6:0] == 7'd0;	

	CCRY		<= cencnt[5:0] == BCLK&HCLK&CLD&PH_6; //6'd16;//

end
	
assign core_pix_clk=BCLK;

//M6502 (Main CPU) address & databus definitions
wire CPU_RESn,CPU_IRQn,CPU_RWn,CPU_nWRITE;
wire [23:0]	CPU_addrbus;
reg  [7:0]  CPU_databus_in;
wire [7:0]  CPU_databus_out;

//register definition
reg  [4:0] M1R, M2R; 		 //W: h5100: Moving Object Rotation Latch
reg  [7:0] CPL; 				 //W: h5101: Control Port Latch
reg  [7:0] EIR; 				 //R: h5103: Interrupt condition latch
wire [7:0] ESR={m_coina,m_down,m_up,m_fire,m_left,m_right,m_start2p,m_start1p}; //h5101: Controller Input Buffer
wire [7:0] DIPSWA={DIP1[7:1],!m_coinb}; //h5101: Controller Input Buffer

wire nWM2V,nWM2H,nWM1V,nWM1H;
wire RAMSEL,ROMSEL,VSEL,MISEL,IOSEL,ABSEL,SRAMSEL,CHARSEL,EXTVID;
assign RAMSEL = CPU_addrbus[15:10]	==	6'b000000 	? 1'b0 : 1'b1;	//ZEROPAGE, SCRATCH RAM
assign SRAMSEL= CPU_addrbus[15:10]	==	6'b010000 	? 1'b0 : 1'b1;	//SCREEN RAM
//assign CHARSEL= CPU_addrbus[15:11]	==	5'b01001 	? 1'b0 : 1'b1;	//Character RAM
assign CHARSEL= pcb[5] ? (CPU_addrbus[15:11]	==	5'b01100 	? 1'b0 : 1'b1) : (CPU_addrbus[15:11]	==	5'b01001 	? 1'b0 : 1'b1);	//Character RAM

assign EXTVID = CPU_addrbus[15:11]  == 5'b01101    ? 1'b0 : 1'b1; //Extended video RAM found in PepperII, FAX etc.

assign ROMSEL = U5C_out[3:0] 			== 4'b0011 		? 1'b0 : 1'b1;	//PROGRAM ROM
assign VSEL   = U5C_out[3:0] 			== 4'b0101 		? 1'b0 : 1'b1;	//VIDEO RAM
assign MISEL  = U5C_out[3:0] 			== 4'b0111 		? 1'b0 : 1'b1;	//MOVING OBJECT
assign IOSEL  = U5C_out[3:0] 			== 4'b1001 		? 1'b0 : 1'b1;	//I/O
assign ABSEL  = U5C_out[3:0] 			== 4'b1011 		? 1'b0 : 1'b1;	//AUDIO BOARD

//IO REGISTER SELECTION
wire   nEIR  = !(!IOSEL & CPU_addrbus[1:0]==2'b11 & CPU_RWn); 	//$5103
wire   nEAD  = !(!IOSEL & CPU_addrbus[1:0]==2'b10 & CPU_RWn); 	//$5102
wire   nESR  = !(!IOSEL & CPU_addrbus[1:0]==2'b01 & CPU_RWn); 	//$5101
wire   nDIP  = !(!IOSEL & CPU_addrbus[1:0]==2'b00 & CPU_RWn); 	//$5100

//MOVING OBJECT (SPRITES) SELECTION
assign nWM2V = (CPU_addrbus[15:0]==16'h50C0 & !CPU_RWn ); //$50C0
assign nWM2H = (CPU_addrbus[15:0]==16'h5080 & !CPU_RWn ); //$5080
assign nWM1V = (CPU_addrbus[15:0]==16'h5040 & !CPU_RWn ); //$5040
assign nWM1H = (CPU_addrbus[15:0]==16'h5000 & !CPU_RWn ); //$5000

wire nWMOL = !(!IOSEL & CPU_addrbus[1:0]==2'b00 & !CPU_RWn); //Moving Object Rotation Latch
wire nWCPL = !(!IOSEL & CPU_addrbus[1:0]==2'b01 & !CPU_RWn); //Control Port Latch

always @(posedge nWMOL) {M2R[3:0],M1R[3:0]}<= CPU_databus_out; //Moving Object Latch 
always @(posedge nWCPL) {ADSEL,M2R[4],M1R[4],CPL[4:0]} <= CPU_databus_out; //Control Port Latch -swapped M2R & M1R for giggles, turns out this is correct & the original schematics are wrong

reg ADSEL;

//CPU read selection logic
// ******* PRIMARY CPU IC SELECTION LOGIC FOR TILE, SPRITE, SOUND & GAME EXECUTION ********
always @(posedge master_clock) begin

		CPU_databus_in <=	   (!RAMSEL			 	 									& CPU_RWn) 	? CPU_RAM_out 		: //RAM
									(!ROMSEL  												& CPU_RWn) 	? CPU_PROM_out 	: //EPROM
									(!SRAMSEL												& CPU_RWn) 	? VRAM_CPU_out 			: //SCREEN RAM
									(!CHARSEL												& CPU_RWn) 	? VRAM_out_CSCG1_CPU 	: //CHARACTER RAM - 11C & 13C
									(!EXTVID													& CPU_RWn) 	? VRAM_out_CSCG2_CPU 	: //CHARACTER RAM - 11C & 13C
									(!IOSEL & CPU_addrbus[1:0]==2'b11 				& CPU_RWn)  ? EIR 				: //INTERRUPT CONDITION LATCH
									(!IOSEL & CPU_addrbus[1:0]==2'b01				& CPU_RWn)  ? ESR 				: //CONTROL INPUTS
									(!IOSEL & CPU_addrbus[1:0]==2'b00				& CPU_RWn)  ? DIPSWA 			: //DIP SWITCHES
									((CPU_addrbus[15:0]>16'h51FF&CPU_addrbus[15:0]<16'h5210)													& CPU_RWn)  ? audio_data_out  : //& CPU_addrbus[4]==1'b0
									(CPU_addrbus[15:0]==16'h5213						& CPU_RWn)  ? IN2 :
									(!CPU_RWn)																? CPU_databus_out : 8'b00000000;

end
	
//6502 main CPU @ .7MHz
T65 M6502(
	.mode(0),
	.res_n(RESET_n),
	.enable(PH_1),
	.clk(master_clock),
	.rdy(~pause),
	.abort_n(1),
	.irq_n(!rCPU_IRQ),
	.nmi_n(1),
	.so_n(1),
	.r_w_n(CPU_RWn),
	.a(CPU_addrbus),
	.di(CPU_databus_in),
	.do(CPU_databus_out)
);

//6502 CPU main program program ROM - This is a combination of all of the program ROMs 
//Full 64K allocated for ease (including shadow ROM for boot sequence)
wire [7:0] CPU_PROM_out;
eprom_0 PROGRAM_MEMORY
(
	.ADDR(CPU_addrbus[15:0]),
	.CLK(master_clock),
	.DATA(CPU_PROM_out),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep0_cs_i),
	.WR(dn_wr)
);

//main CPU (6502) 1K of work RAM - dual port RAM for hi-score logic
wire [7:0] CPU_RAM_out;
dpram_dc #(.widthad_a(10)) U14_RAM_2016 //SJ
(
	.clock_a(master_clock),
	.address_a(CPU_addrbus[9:0]),
	.data_a(CPU_databus_out),
	.wren_a(!CPU_RWn & !RAMSEL), 
	.q_a(CPU_RAM_out),

	.clock_b(master_clock),
	.address_b(hs_address[9:0]),
	.data_b(hs_data_in),
	.wren_b(hs_write),
	.q_b(hs_data_out)
	
);

	
//graphics ROM: 2708 (1K) or 2716 (2K)
wire [7:0] MVD;
eprom_1 U11D_gfx
(
	.ADDR(SPRITE_ADDR),
	.CLK(master_clock),
	.DATA(MVD),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep1_cs_i),
	.WR(dn_wr)
);

wire [3:0] U5C_out;
eprom_2 U5C_memmap
(
	.ADDR(CPU_addrbus[15:8]),
	.CLK(master_clock),
	.DATA(U5C_out),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep2_cs_i),
	.WR(dn_wr)
);


//VIDEO RAM CONTROL PROM
wire CSSR,CSCG1,CSCG2,X5ESBD,XECGBD,DBDIR,SWR,ESBD;
eprom_3 U6D_VRAMCTRL
(
	.ADDR({PH_1,VSEL,CPU_addrbus[11],CPU_addrbus[10]/*VD7[10]*/,CPU_RWn}), //VD7AI0 replaced with CPU:A10
	.CLK(master_clock),
	.DATA({CSSR,CSCG1,CSCG2,X5ESBD,XECGBD,DBDIR,SWR,ESBD}),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep3_cs_i),
	.WR(dn_wr)
);

wire GSWR=!(CLD&SWR);

//reg [9:0] SCREENRAM_ADDR ;
//always @(posedge master_clock) SCREENRAM_ADDR <= ESBD ? {CPU_addrbus[9:3],CPU_addrbus[0],CPU_addrbus[1],CPU_addrbus[2]}:{vscnt[7:3],hscnt[4:3],hscnt[0],hscnt[1],hscnt[2]};

wire [7:0] VRAM_out,VRAM_out_CSCG1,VRAM_out_CSCG2;
wire [7:0] VRAM_out_CSCG1_CPU,VRAM_out_CSCG2_CPU,VRAM_CPU_out;

dpram_dc #(.widthad_a(10)) VRAM_2114 
(
	.clock_a(master_clock),
	.address_a({vscnt[7:3],hscnt[4:0]}), //vertical position 0-31, horizontal position 0-31.  32x32 grid of 8x8 pixels (characters)
	.data_a(),
	.wren_a(1'b0),
	.q_a(VDA), //VRAM_out

	.clock_B(master_clock),
	.address_B({CPU_addrbus[9:0]}),
	.data_B(CPU_databus_out),
	.wren_B(!CPU_RWn & !SRAMSEL),//!GSWR //CLD & 
	.q_B(VRAM_CPU_out)
);


wire [7:0] VDA; //output of U7C
reg X1VLV1,X6E256;


dpram_dc #(.widthad_a(11)) VRAM_2114_CSCG1 
(
	.clock_a(master_clock),
	.address_a({VDA[7:0],vscnt[2:0]} ),	
	.data_a(),
	.wren_a(1'b0),
	.q_a(VRAM_out_CSCG1),
	
	.clock_b(master_clock),
	.address_b(CPU_addrbus[10:0]),	
	.data_b(CPU_databus_out),
	.wren_b(!CPU_RWn & !CHARSEL), 
	.q_b(VRAM_out_CSCG1_CPU)
);

dpram_dc #(.widthad_a(11)) VRAM_2114_CSCG2 
(
	.clock_a(master_clock),
	.address_a({VDA[7:0],vscnt[2:0]} ),	
	.data_a(),
	.wren_a(1'b0),
	.q_a(VRAM_out_CSCG2),
	
	.clock_b(master_clock),
	.address_b(CPU_addrbus[10:0]),	
	.data_b(CPU_databus_out),
	.wren_b(!CPU_RWn & !EXTVID), 
	.q_b(VRAM_out_CSCG2_CPU)
);

wire VIVY;
oLS166 U4_VIVY(
	.clk(BCLK),
	.CE(1'b0),
	.S(1'b0),
	.pin(VRAM_out_CSCG2),
	.PE(X5SRLD),  
	.clr(nCBLB),
	.QH(VIVY)
);

//******************* MOVING OBJECT **********************
//MOVING OBJECT LATCHES
reg [7:0] M1H,M2H,M1V,M2V; 			//sprite counters
reg [7:0] rM1H,rM2H,rM1V,rM2V;		//sprite position latches
wire M1HW,M2HW,M1VW,M2VW,M1W,M2W;	//window set bits
wire nESR4,nESR3,nESR2,nESR1;
wire EM1VID,EM2VID,nM01VDT,nM02VDT; //outputs (pixels & window open)

//wire MHCLK=!(nCBLB&BCLK); 

always @(posedge nWM1H) rM1H<=CPU_databus_out;
always @(posedge nWM1V) rM1V<=CPU_databus_out+8'd1;
always @(posedge nWM2H) rM2H<=CPU_databus_out;
always @(posedge nWM2V) rM2V<=CPU_databus_out+8'd1;

always @(posedge BCLK) begin
	M1H <= (nCBLB) ? M1H+8'd1 : rM1H;
	M2H <= (nCBLB) ? M2H+8'd1 : rM2H;
end

always @(posedge CBLB) begin
	M1V <=   vscnt==9'd0 ? rM1V : M1V+8'd1; 
	M2V <=   vscnt==9'd0 ? rM2V : M2V+8'd1; 
end

//Draw sprite when top 4 bits of counter are set
//this is a window of 16 x 16 pixels 
//assign	M1HW = (M1H[7:4]==4'b1111);
//assign	M2HW = (M2H[7:4]==4'b1111);
//assign	M1VW = (M1V[7:4]==4'b1111);
//assign 	M2VW = (M2V[7:4]==4'b1111);	

//assign M1W = !(M1HW & M1VW);  //SPRITE #1 WINDOW
//assign M2W = !(M2HW & M2VW);	//SPRITE #2 WINDOW

wire [10:0] SPRITE_ADDR;
//bit M2R[4] is not working
assign SPRITE_ADDR = hscnt[2] ? {1'b1,M2R[4:0],hscnt[1],M2V[3:0]} : {1'b0|!pcb[4],M1R[4:0],hscnt[1],M1V[3:0]}; 

//Sprite trigger: !E8 & PH_6 & E64 & E256
wire nELOAD = !(!hscnt[0] & PH_6 & hscnt[3] & hscnt[5]); 
wire LSR1 = !(!nELOAD & hscnt[2:1] == 2'b00);
wire LSR2 = !(!nELOAD & hscnt[2:1] == 2'b01);
wire LSR3 = !(!nELOAD & hscnt[2:1] == 2'b10);
wire LSR4 = !(!nELOAD & hscnt[2:1] == 2'b11);

wire M1V_out,M2V_out,M1VID,M2VID;
wire [1:0] U14_dummy_out;

//Sprite control PROM
eprom_4 U14H_SPCTRL
(
	.ADDR({nELOAD,hscnt[1],hscnt[2],!((M1H[7:4]==4'b1111) & (M1V[7:4]==4'b1111)),!((M2H[7:4]==4'b1111) & (M2V[7:4]==4'b1111))}), 
	.CLK(master_clock),
	.DATA({U14_dummy_out[1:0],EM2VID,EM1VID,nESR4,nESR3,nESR2,nESR1}),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep4_cs_i),
	.WR(dn_wr)
);

//sprite pixel output shifters
oLS166 U13D_M1VA(
	.clk(BCLK&LSR2&!nESR2&nCBLB),
	.CE(1'b0),
	.S(1'b0),
	.pin(MVD),  //MVD
	.PE(LSR2),
	.clr(1'b1),
	.QH(M1V_out)
);

oLS166 U12D_M1VA(
	.clk(BCLK&LSR1&!nESR1&nCBLB),
	.CE(1'b0),
	.S(M1V_out),
	.pin(MVD), //MVD
	.PE(LSR1),
	.clr(1'b1),
	.QH(M1VID)
);

oLS166 U15D_M1VA(
	.clk(BCLK&LSR4&!nESR4&nCBLB),
	.CE(1'b0),	
	.S(1'b0),
	.pin(MVD),
	.PE(LSR4),
	.clr(1'b1),
	.QH(M2V_out)
);

oLS166 U14D_M1VA(
	.clk(BCLK&LSR3&!nESR3&nCBLB),
	.CE(1'b0),
	.S(M2V_out),		
	.pin(MVD),
	.PE(LSR3),
	.clr(1'b1),
	.QH(M2VID)
);

//Sprite Window
assign nM01VDT=!(EM1VID & M1VID);
assign nM02VDT=!(EM2VID & M2VID);

//************** END OF MOVING OBJECT ********************

always @(posedge PH_1)  X6E256<=!hscnt[5];
wire X5SRLD=!(PH_6B&!hscnt[5]);//CCRY&&

wire SGCVID,nSGCVID;

//character generation pixel output
oLS166 U12B_CHAR_OUT(
	.clk(BCLK),  //
	.CE(1'b0),	
	.S(1'b0),	
	.pin(VRAM_out_CSCG1), //VD
	.PE(X5SRLD),
	.clr(nCBLB), //!BLANK
	.QH(SGCVID)
);
assign nSGCVID=!SGCVID;

//capture colour data
reg  [1:0] col_cap;
wire [2:0] col_sel_idx;
reg  [3:0] char_col;

always @(posedge X5SRLD) col_cap<=VDA[7:6];//VD7[10:9]; // pcb[5] ? {VDA[7],VIVY} : 


always @(posedge master_clock) begin

	if (pcb[5]==1'b0) begin
	
		case ({col_cap[1:0],nSGCVID})
			3'b000 : char_col<=(pcb[4] ? 4'b1110 : 4'b0111);		
			3'b010 : char_col<=(pcb[4] ? 4'b1101 : 4'b1011);		
			3'b100 : char_col<=(pcb[4] ? 4'b1011 : 4'b1101);		
			3'b110 : char_col<=(pcb[4] ? 4'b0111 : 4'b1110);	
			default: char_col<=4'b1111;
		endcase
	end
	else begin
		case ({col_cap[1],VIVY,nSGCVID})
			3'b000 : char_col<=4'b1110;
			3'b010 : char_col<=4'b1101;
			3'b100 : char_col<=4'b1011;
			3'b110 : char_col<=4'b0111;
			default: char_col<=4'b1111;
		endcase
	
	end

end

//background colour (always on), character colour (1-4), always off, sprite 2, sprite 1
LS148_encoder colour_sel (
    .in({1'b0,char_col,1'b1,nM02VDT,nM01VDT}), //
    .S(col_sel_idx)
);

wire [7:0] audio_data_out;

//audio board
exidyAB sound_board(
	.PH_1(PH_1),
	.audio_clk(audio_clk),
	.RESET_n(RESET_n),
	.ABSEL(ABSEL),
	.CPU_RWn(CPU_RWn),
	.CPU_addrbus(CPU_addrbus[15:0]),
	.CPU_databus_out(CPU_databus_out[7:0]),
	.pcb(pcb[7:0]),
	.master_clock(master_clock),
	.pause(pause),
	.dn_addr(dn_addr),
	.dn_data(dn_data),
	.ep5_cs_i(ep5_cs_i),
	.ep6_cs_i(ep6_cs_i),	
	.dn_wr(dn_wr),	
	.audio_data_out(audio_data_out),
	.audio_l(audio_l),
	.audio_r(audio_r)
);

//------------------------------------------------- MiSTer data write selector -------------------------------------------------//
//Instantiate MiSTer data write selector to generate write enables for loading ROMs into the FPGA's BRAM
wire ep0_cs_i, ep0b_cs_i, ep1_cs_i, ep2_cs_i, ep3_cs_i, ep4_cs_i, ep5_cs_i, ep6_cs_i, ep7_cs_i, ep8_cs_i,ep9_cs_i,ep10_cs_i,ep11_cs_i,ep12_cs_i,ep13_cs_i,cp1_cs_i,cp2_cs_i,cp3_cs_i;

selector DLSEL
(
	.ioctl_addr(dn_addr),
	.ep0_cs(ep0_cs_i),
	.ep1_cs(ep1_cs_i),
	.ep2_cs(ep2_cs_i),
	.ep3_cs(ep3_cs_i),
	.ep4_cs(ep4_cs_i),
	.ep5_cs(ep5_cs_i),
	.ep6_cs(ep6_cs_i),
	.ep7_cs(ep7_cs_i),	
	.ep8_cs(ep8_cs_i),
	.ep9_cs(ep9_cs_i),	
	.ep10_cs(ep10_cs_i),
	.ep11_cs(ep11_cs_i),
	.ep12_cs(ep12_cs_i),
	.ep13_cs(ep13_cs_i),
	.cp1_cs(cp1_cs_i),
	.cp2_cs(cp2_cs_i),
	.cp3_cs(cp3_cs_i)	
);


	
//HORIZONTAL & VERTIAL COUNTERS & SYNC LOGIC
reg [5:0] hscnt =6'd0; //horizontal counter
reg [5:0] hspcnt=6'd0; //horizontal prev counter
//horizontal
always @(posedge PH_1) begin
	//hscnt  <= (hscnt[5:0]==6'b100000) ? 6'd55 : hscnt+6'd1;
	hscnt  <= (hscnt[5:0]==6'b100000) ? mod_shift[5:0] : hscnt+6'd1;
end
assign H_SYNC =   (hscnt>61) ? 1'b1 : 1'b0;
always @(negedge BCLK) hspcnt<=hscnt;

//vertical
reg VL1;
reg [8:0] vscnt =9'd0; //vertical counter

always @(posedge BCLK) begin
	vscnt <= (vscnt==9'd280) ? 9'd0 : 
				(hscnt==61 & hspcnt==60) ? vscnt+9'd1 : vscnt;
	VL1  <= ((vscnt==9'd256)&(hscnt==60)); //256
end

//	vscnt <= (vscnt==9'd280) ? 9'd0 : 
//				(hscnt==61 & hspcnt==60) ? vscnt+9'd1 : vscnt;
//	VL1  <= ((vscnt==9'd270)&(hscnt==60)); //256
//program is crashing when going down stairs on play.  hspcnt is set to 60


//sync / blanking
assign V_SYNC  = (vscnt>274) ? 1'b1 : 1'b0; //264 = 17.64 , 63 //264
assign V_BLANK = vscnt[8];
assign H_BLANK = hscnt[5];
wire nCBLB=!vscnt[8]&!hscnt[5];
wire CBLB=!nCBLB;
wire BLANK = (V_BLANK|H_BLANK);
//wire nVCCCRY = !(vscnt[7:4]==4'b1111);

reg 	[7:0] red_jmp,grn_jmp,blu_jmp; //RGB jumpers 
reg 	[7:0] RED_LATCH,GRN_LATCH,BLU_LATCH,IN2; //RGB Latches

//RGB colour selection found on enhanced Audio / Colour Adapter Board 
always @(posedge BCLK) begin
	if (CPU_RWn==0 & CPU_addrbus[15:2]==14'b01010010000100) begin
		case (CPU_addrbus[1:0])
			2'b00 : BLU_LATCH<=CPU_databus_out;
			2'b01 : GRN_LATCH<=CPU_databus_out;
			2'b10 : RED_LATCH<=CPU_databus_out;		
			//2'b11 : IN2		  <=CPU_databus_out;					
		endcase
	end
end
always @(*) IN2<={4'b0000,m_blu,1'b1,m_red,m_yel};

//set colour 'jumpers' based on PCB configuration
always @(*) begin
	if (pcb[4]) begin
		red_jmp<=RED_LATCH;
		grn_jmp<=GRN_LATCH;
		blu_jmp<=BLU_LATCH;
	end
	else begin
		case (pcb[1:0])
			2'b00 	:	begin
								red_jmp = 8'b00000001; //B&W (SideTrac)
								grn_jmp = 8'b00000001;
								blu_jmp = 8'b00000001;
							end
			2'b01		:  begin
								red_jmp = 8'b01001010; //COlour DIP (Targ)
								grn_jmp = 8'b11111100;
								blu_jmp = 8'b01110101;
							end
			2'b10		:  begin
								red_jmp = 8'b11010110; //COlour DIP (Spectar)
								grn_jmp = 8'b11111100;
								blu_jmp = 8'b01100001;			
							end
			default 	: 	begin
								red_jmp = 8'b00000000; //Unknown
								grn_jmp = 8'b00000000;
								blu_jmp = 8'b00000000;						
							end
		endcase
	end
end	

//RGB output
always @(posedge BCLK) begin
	RED 	<= red_jmp[col_sel_idx];
	GREEN <= grn_jmp[col_sel_idx];
	BLUE 	<= blu_jmp[col_sel_idx];
end	
//wire M1CHAR=!((nSGCVID|nM01VDT)|CBLB);
//wire M1M2  =!(nM01VDT|nM02VDT);
reg cDET,rCPU_IRQ,COINT;
always @(*) cDET<=!((!((!(nM01VDT|nSGCVID))|(!(nM02VDT|nSGCVID))))|CBLB);//collision detection
//wire cDET=1'b0;
//trigger output is set by 1VL1 and cleared by reading EIR

always @(posedge master_clock) COINT<=(!m_coina|!m_coinb);
always @(negedge BCLK or negedge COINT or negedge nEIR) rCPU_IRQ = (rCPU_IRQ|VL1|COINT|cDET)&nEIR; //
//targ interrupt configuration
//always @(posedge rCPU_IRQ) EIR <= {!vscnt[8],!m_coina,!m_coinb,5'b11111};//<5L256,COIN1,COIN2,VDLV,5CVID,5MO2VID,5MO1VID,HDLV
//spectar interrupt configuration
//always @(posedge rCPU_IRQ) EIR <= {!vscnt[8],!m_coina,!m_coinb,1'b1,1'b0,nM01VDT,2'b00};//<5L256,COIN1,COIN2,VDLV,5CVID,5MO2VID,5MO1VID,HDLV -- works with most
always @(posedge rCPU_IRQ) EIR <= {!vscnt[8],!m_coina,!m_coinb,!(nM01VDT|nM02VDT),1'b0,!((nSGCVID|nM01VDT)|CBLB),2'b00};//<5L256,COIN1,COIN2,VDLV,5CVID,5MO2VID,5MO1VID,HDLV

wire VDLV=!(X5SRLD|vscnt[0]);
//assign CPU_IRQn=!rCPU_IRQ; //VDLV

endmodule
