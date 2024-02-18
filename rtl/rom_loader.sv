//============================================================================
// 
//  SD card ROM loader and ROM selector for MISTer.
//  Copyright (C) 2019 Kitrinx (aka Rysha)
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//	 the rights to use, copy, modify, merge, publish, distribute, sublicense,
//	 and/or sell copies of the Software, and to permit persons to whom the 
//	 Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//	 all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//	 DEALINGS IN THE SOFTWARE.
//
//============================================================================

module selector
(
	input logic [24:0] ioctl_addr,
	output logic ep0_cs, ep1_cs, ep2_cs, ep3_cs, ep4_cs, ep5_cs, ep6_cs, ep7_cs, ep8_cs, ep9_cs, ep10_cs, ep11_cs, ep12_cs, ep13_cs,cp1_cs,cp2_cs,cp3_cs
);

	always_comb begin
		{ep0_cs, ep1_cs, ep2_cs, ep3_cs, ep4_cs, ep5_cs, ep6_cs, ep7_cs, ep8_cs, ep9_cs, ep10_cs, ep11_cs, ep12_cs, ep13_cs,cp1_cs,cp2_cs,cp3_cs} = 0;


		if     (ioctl_addr < 'h10000) ep0_cs = 1; // 0x10000 16   - Program ROM 
		else if(ioctl_addr < 'h14000) ep6_cs = 1; // 0x04000 15   - Audio Program ROM
		else if(ioctl_addr < 'h14800) ep1_cs = 1; // 0x00800 10   - Graphics
		else if(ioctl_addr < 'h14900) ep2_cs = 1; // 0x00100  8   - Address Decoder
		else if(ioctl_addr < 'h14920) ep3_cs = 1; // 0x00020  8   - VRAM Control
		else if(ioctl_addr < 'h14940) ep4_cs = 1; // 0x00020  8   - Sprite Control
		else if(ioctl_addr < 'h14960) ep5_cs = 1; // 0x00020  8   - Tone

		/*else if(ioctl_addr < 'h30000) ep7_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h38000) ep8_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h40000) ep9_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h48000) ep10_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h50000) ep11_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h58000) ep12_cs = 1; // 0x8000 14	- 

		else if(ioctl_addr < 'h58100) cp1_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h58200) cp2_cs = 1; // 0x8000 14	- 
		else if(ioctl_addr < 'h58300) cp3_cs = 1; // 0x8000 14	-  */

		else ep7_cs = 1; // 0x8000 14	- 

	end
endmodule

////////////
// EPROMS //
////////////

module eprom_0 //program
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic        CEN,
	input logic [15:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);

	dpram_dc #(.widthad_a(16)) eprom_0
	(
		.clock_a(CLK),
		.address_a(ADDR[15:0]),
		.q_a(DATA),
		.clock_b(CLK_DL),
		.address_b(ADDR_DL[15:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_1 //graphics 
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [10:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);

	dpram_dc #(.widthad_a(11)) eprom_1
	(
		.clock_a(CLK),
		.address_a(ADDR[10:0]),
		.q_a(DATA),
		.clock_b(CLK_DL),
		.address_b(ADDR_DL[10:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_2  //memory mapper
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic        CEN,	
	input logic [7:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [3:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [3:0] DATA
);
	
	dpram_dc #(.widthad_a(8)) eprom_2
	(
		.clock_a(CLK),
		.address_a(ADDR[7:0]),
		.q_a(DATA),
		.clock_b(CLK_DL),
		.address_b(ADDR_DL[7:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule



module eprom_3 //vram control
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [4:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);

	dpram_dc #(.widthad_a(5)) eprom_3
	(
		.clock_a(CLK),
		.address_a(ADDR[4:0]),
		.q_a(DATA[7:0]),
		.clock_b(CLK_DL),
		.address_b(ADDR_DL[4:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule



module eprom_4 //sprite
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [4:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(5)) eprom_4
	(
		.clock_a(CLK),
		.address_a(ADDR[4:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[4:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_5 //tone data
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [4:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(5)) eprom_5
	(
		.clock_a(CLK),
		.address_a(ADDR[4:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[4:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule


module eprom_6
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [13:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(14)) eprom_6
	(
		.clock_a(CLK),
		.address_a(ADDR[13:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[13:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule



module eprom_7
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [13:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(14)) eprom_7
	(
		.clock_a(CLK),
		.address_a(ADDR[13:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[13:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule


module eprom_8
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [14:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(15)) eprom_8
	(
		.clock_a(CLK),
		.address_a(ADDR[14:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[14:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_9
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [14:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(15)) eprom_9
	(
		.clock_a(CLK),
		.address_a(ADDR[14:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[14:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_10
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [14:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(15)) eprom_10
	(
		.clock_a(CLK),
		.address_a(ADDR[14:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[14:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_11
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [14:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(15)) eprom_11
	(
		.clock_a(CLK),
		.address_a(ADDR[14:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[14:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module eprom_12
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [14:0] ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [7:0] DATA
);
	dpram_dc #(.widthad_a(15)) eprom_12
	(
		.clock_a(CLK),
		.address_a(ADDR[14:0]),
		.q_a(DATA[7:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[14:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

///////////
// PROMS //
///////////

module cprom_1
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [7:0]  ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [3:0] DATA
);
	dpram_dc #(.widthad_a(8)) cprom_1
	(
		.clock_a(CLK),
		.address_a(ADDR),
		.q_a(DATA[3:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[7:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module cprom_2
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [7:0]  ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [3:0] DATA
);
	dpram_dc #(.widthad_a(8)) cprom_2
	(
		.clock_a(CLK),
		.address_a(ADDR),
		.q_a(DATA[3:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[7:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule

module cprom_3
(
	input logic        CLK,
	input logic        CLK_DL,
	input logic [7:0]  ADDR,
	input logic [24:0] ADDR_DL,
	input logic [7:0]  DATA_IN,
	input logic        CS_DL,
	input logic        WR,
	output logic [3:0] DATA
);
	dpram_dc #(.widthad_a(8)) cprom_3
	(
		.clock_a(CLK),
		.address_a(ADDR),
		.q_a(DATA[3:0]),

		.clock_b(CLK_DL),
		.address_b(ADDR_DL[7:0]),
		.data_b(DATA_IN),
		.wren_b(WR & CS_DL)
	);
endmodule
