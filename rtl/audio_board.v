module exidyAB (
	input  PH_1,
	input  audio_clk,
	input  RESET_n,
	input  ABSEL,
	input  CPU_RWn,
	input  [15:0] CPU_addrbus,
	input  [7:0]  CPU_databus_out,
	input  [7:0]  pcb,
	input  pause,
	
	input master_clock,
	input [24:0] dn_addr,
	input [7:0]  dn_data,
	input ep5_cs_i,
	input ep6_cs_i,	
	input dn_wr,

	output [7:0] audio_data_out,
	output signed [15:0] audio_l,
	output signed [15:0] audio_r
);

//clock enables
reg [3:0] cencnt_au =4'd0;
reg auCLK,auPH0,auPH0B;

always @(posedge audio_clk) begin
	cencnt_au  <= cencnt_au+4'd1;
end

always @(posedge audio_clk) begin //14.366883
	//[0] 	7.15909
	//[1:0]	3.579545
	auCLK	  	<= cencnt_au[2:0] == 3'd0; 	//[2:0]  1.789773
	auPH0	  	<= cencnt_au[3:0]	== 4'd0;		//[2:0]  0.894886
	auPH0B  	<= cencnt_au[3:0]	== 4'd1;

end

//Audio CPU running at 0.894886 MHz
T65 A6502(
	.mode(0),
	.res_n(RESET_n),
	.enable(auPH0),
	.clk(audio_clk),
	.rdy(~pause),
	.abort_n(1),
	.irq_n(!audio_irq),
	.nmi_n(1),
	.so_n(1),
	.r_w_n(audio_nWRITE),
	.a(audio_addrbus[15:0]),
	.di(audio_databus_in),
	.do(audio_databus_out)
);

//CPU databus IN:
wire	[7:0]	audio_databus_in = 	(!io00_07 & audio_nWRITE)				? audio_RAM_out 			: 
											(!io08_0F & audio_nWRITE)				? audio_data_io			:
											(!io10_17 & audio_nWRITE)				? audio_data_PIAB_out	:
											(!AROMSEL & audio_nWRITE) 				? audio_prog_data 		:
											(!audio_nWRITE)							? audio_databus_out 		: 8'b00000000;

wire audio_irq=(!RIOT_IRQ||PIB_IRQA||PIB_IRQB);
wire RIOT_IRQ;

//this RIOT implementation does not include the RAM
R6532 A6532_RIOT(
    .phi2(auPH0),	
    .rw_n(audio_nWRITE),
	 .rst_n(RESET_n),
    .cs(!io08_0F),		
    .irq_n(RIOT_IRQ),
    .add(audio_addrbus[4:0]),
    .din(audio_databus_out),		
	 .dout(audio_data_io)
);

//RIOT RAM
wire [7:0] audio_RAM_out;
dpram_dc #(.widthad_a(11)) AUDIO_RAM //expanded ram for a test
(
	.clock_a(audio_clk),
	.address_a(audio_addrbus[10:0]),
	.data_a(audio_databus_out),
	.wren_a(!audio_nWRITE & !io00_07), 
	.q_a(audio_RAM_out)
);

wire PIB_IRQA,PIB_IRQB;
wire PIA_8B_CA2_out,PIA_8B_CB2_out,PIA_9B_CA2_out,PIA_9B_CB2_out;
wire [7:0] audio_DI_bus,audio_DO_bus;

//The PIAs @9B & 8B of the audio expansion board provide a handshake between the main CPU and the audio CPU
pia6821 PIA_9B( //MAIN CPU INTERFACE
	.clk(master_clock), //PH_1
	.rst(!RESET_n),
	.cs((CPU_addrbus[15:0]>=16'h5200&CPU_addrbus[15:0]<=16'h520F)),
	.rw(CPU_RWn),
	.addr(CPU_addrbus[1:0]),
	.data_in(CPU_databus_out),
	.data_out(audio_data_out),
	.irqa(),
	.irqb(),

	.pa_i(audio_DO_bus),
	.pa_o(),
	.pa_oe(),
	.pa_ddr_ovrd(),

	.ca1(PIA_8B_CB2_out),
	.ca2_i(1'b0),
	.ca2_o(PIA_9B_CA2_out),
	.ca2_oe(),

	.pb_i(),
	.pb_o(audio_DI_bus),
	.pb_oe(),

	.cb1(PIA_8B_CA2_out),
	.cb2_i(1'b0),
	.cb2_o(PIA_9B_CB2_out),
	.cb2_oe()
);

pia6821 PIA_8B( //AUDIO CPU INTERFACE
	.clk(audio_clk), //
	.rst(!RESET_n),
	.cs(!io10_17),
	.rw(audio_nWRITE),
	.addr(audio_addrbus[1:0]),
	.data_in(audio_databus_out),
	.data_out(audio_data_PIAB_out),
	.irqa(PIB_IRQA),
	.irqb(PIB_IRQB),

	.pa_i(audio_DI_bus),
	.pa_o(),
	.pa_oe(),
	.pa_ddr_ovrd(),

	.ca1(PIA_9B_CB2_out),
	.ca2_i(1'b0),
	.ca2_o(PIA_8B_CA2_out),
	.ca2_oe(),

	.pb_i(),
	.pb_o(audio_DO_bus),
	.pb_oe(),

	.cb1(PIA_9B_CA2_out),
	.cb2_i(1'b0),
	.cb2_o(PIA_8B_CB2_out),
	.cb2_oe()
);

wire [11:0] U3D_6840_sound;
wire [7:0] audio_data_PIAB_out,audio_data_io;
wire signed [8:0] snd1,snd2,snd3;

berzerk_sound_fx U3D_6840(
	.clock(auPH0B), //auPH0
	.reset(!RESET_n),
	.cs(!io28_2F & !audio_nWRITE),
	.vs(!io30_37 & !audio_nWRITE),
	.addr({2'b00,audio_addrbus[2:0]}),
	.di(audio_databus_out),
   .sample(U3D_6840_sound),
	.snd1(snd1),
	.snd2(snd2),
	.snd3(snd3)
);

////////////////////   SOUND   //////////////////// - THIS MODULE WAS LIFTED FROM : https://github.com/MiSTer-devel/Vector-06C_MiSTer/blob/master/Vector-06C.sv
wire [7:0] i8253_data_out;
wire wr8253=(!audio_nWRITE & !io18_1F);
wire [2:0] i8253_audio_out;
wire [2:0] i8253_active;
wire [2:0] i8253_snd = i8253_audio_out & i8253_active;

k580vi53 i8253_2B
(
	.reset(!RESET_n),
	.clk_sys(audio_clk),
	.clk_timer({!auCLK,!auCLK,!auCLK}),
	.addr(audio_addrbus[1:0]),
	.wr(wr8253),
	.rd(1'b0),
	.din(audio_databus_out),
	.dout(i8253_data_out),
	.gate(3'b111),
	.out(i8253_audio_out),
	.sound_active(i8253_active)
);


wire audio_nWRITE;
wire [23:0] audio_addrbus;
wire [7:0] audio_databus_out;

wire io00_07=!(audio_addrbus[15:11]==5'b00000); //7B 6532 - RIOT
wire io08_0F=!(audio_addrbus[15:11]==5'b00001); //7B 6532 - RIOT
wire io10_17=!(audio_addrbus[15:11]==5'b00010); //8B 6520 - PIA
wire io18_1F=!(audio_addrbus[15:11]==5'b00011); //2B 8253 - AUDIO CHIP
wire io20_27=!(audio_addrbus[15:11]==5'b00100); //ENABLES 
wire io28_2F=!(audio_addrbus[15:11]==5'b00101); //3D 6840 - PROGRAMMABLE TIMER MODULE
wire io30_37=!(audio_addrbus[15:11]==5'b00110); //9A LS139
wire io38_3F=!(audio_addrbus[15:11]==5'b00111); //

wire AROMSEL=!(audio_addrbus[15:0]>=16'h5800&audio_addrbus[15:0]<=16'hFFFF);

//Audio Board : TARG TONE GENERATOR
//wire UPPER,NOTE;
//assign UPPER = WODD_LATCH[1];
//assign NOTE  = WODD_LATCH[0];
reg GAME,LONG,CRASH,nSPEC,nWARN,ABdummy2,SHOOT,MUSIC;
reg [7:0] WODD_LATCH;
reg [7:0] ABDATA;
reg [3:0] U2A_counter;
reg [7:0] U1AB_counter;
reg [7:0] U3AB_counter;
reg NINC,TONE_out;
wire TC10 = (U1AB_counter[7:0]==8'b11111111);
wire TNEX = (U3AB_counter[7:0]==8'b11111111);
wire [7:0] U3AB_counter_rst;
wire [7:0] U3A_rstv;

//latch data from the main CPU - these addresses are used in TARG/SPECTAR but not in the more advanced audio boards like Venture etc.
wire WEVEN = !ABSEL & !CPU_RWn & !CPU_addrbus[0]; //16'h5200
wire WODD  = !ABSEL & !CPU_RWn &  CPU_addrbus[0]; //16'h5201

always @(posedge WODD) 	WODD_LATCH <= CPU_databus_out[7:0];
always @(posedge WEVEN) {GAME,LONG,CRASH,nSPEC,nWARN,ABdummy2,SHOOT,MUSIC} <= CPU_databus_out[7:0];

always @(posedge PH_1) 						NINC <= WODD_LATCH[0] & GAME;
always @(posedge NINC or negedge GAME) U2A_counter  <= (!GAME) ? 4'd0 : U2A_counter+4'd1;
always @(posedge PH_1) 						U1AB_counter <= (TC10)  ? 8'b10111001  : U1AB_counter+8'd1;
always @(posedge TC10) 						U3AB_counter <= (TNEX)  ? ((pcb[4:0]==5'b00010) ? WODD_LATCH : U3AB_counter_rst) : U3AB_counter+8'd1; //U3A_rstv 			
always @(posedge TNEX) 						TONE_out<=(!TONE_out|!GAME)&(NINC|(pcb[4:0]==5'b00010));

wire signed [15:0] audio_snd;
wire signed [15:0] audio_snd_ext;

parameter       CLKDIV=3;
wire cen16, cen256;

jt49_cen #(.CLKDIV(CLKDIV)) u_cen(
    .clk    ( audio_clk    ),
    .rst_n  ( RESET_n   	),
    .cen    ( auPH0  		),
    .sel    ( 1'b0     		),
    .cen16  ( cen16   		),
    .cen256 ( cen256  		)
);

//two main types of audio board pcb[4] = CPU based board with i8253 and MC6840

jtframe_jt49_filters u_filters1(
            .rst    ( !RESET_n    ),
            .clk    ( audio_clk   ),
            .din0   ( pcb[4] ? {4'b0000,i8253_audio_out[0],   5'b00000} : {4'b0000,MUSIC,   5'b00000}),
            .din1   ( pcb[4] ? {4'b0000,i8253_audio_out[1],   5'b00000} : {4'b0000,MUSIC,   5'b00000}), 
				.din2   ( pcb[4] ? {4'b0000,i8253_audio_out[2],   5'b00000} : {4'b0000,MUSIC,   5'b00000}), 
            .sample ( cen16  ),
            .dout   ( audio_snd    )
);

jtframe_jt49_filters u_filters2(
            .rst    ( !RESET_n    ),
            .clk    ( audio_clk   ),
            .din0   ( pcb[4] ? snd1 : {4'b0000,TONE_out,5'b00000}),
            .din1   ( pcb[4] ? snd2 : {4'b0000,TONE_out,5'b00000}), 
				.din2   ( pcb[4] ? snd3 : {4'b0000,TONE_out,5'b00000}), 
            .sample ( cen16  ),
            .dout   ( audio_snd_ext    )
);

//audio board output
assign audio_l=(pause) ? 16'd0 : audio_snd;
assign audio_r=(pause) ? 16'd0 : audio_snd_ext;

//TARG Tone PROM
eprom_5 HRA2B
(
	.ADDR({WODD_LATCH[1],U2A_counter}), 
	.CLK(master_clock),
	.DATA(U3AB_counter_rst),
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep5_cs_i),
	.WR(dn_wr)
);

wire [7:0] audio_prog_data;

eprom_6 audio_program
(
	.ADDR(audio_addrbus[13:0]), 
	.CLK(audio_clk),
	.DATA(audio_prog_data),
	
	.ADDR_DL(dn_addr),
	.CLK_DL(master_clock),
	.DATA_IN(dn_data),
	.CS_DL(ep6_cs_i),
	.WR(dn_wr)
);

endmodule
