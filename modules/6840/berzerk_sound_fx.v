//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2024, Open Gateware authors and contributors
//------------------------------------------------------------------------------
//
// Berzerk Sound Effects
// This is a derivative work based on the VHDL code by Dar
//
// Updated 2024 for Exidy Core, Anton Gale
// Copyright (c) 2024, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2018, Dar <darfpga@aol.fr>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------

`default_nettype none

module berzerk_sound_fx
    (
        input  wire        clock,
        input  wire        reset,
        input  wire        cs,
        input  wire        vs,
        input  wire  [2:0] addr,
        input  wire  [7:0] di,
        output wire [11:0] sample
    );

    // -------------------------------------------------------------------------
    // Make Enable Signal To Replace Misc Clocks
    // -------------------------------------------------------------------------
    reg [1:0] hdiv;
    reg       ena_q1_clock;
    reg       ena_internal_clock;
    reg       ena_external_clock;
    reg       noise_shift_reg_95_r;

    always @(posedge clock) begin
        // ptm_6840 E input pin (internal clock)
        // board input clock divide by 4
        if(hdiv == 2'b11) begin hdiv <= 2'd0;        ena_internal_clock <= 1'b1; end
        else              begin hdiv <= hdiv + 2'd1; ena_internal_clock <= 1'b0; end

        // ptm6840_q1 is used for alternate noise generator clock
        ptm6840_q1_r <= ptm6840_q1;
        ena_q1_clock <= (!ptm6840_q1_r && ptm6840_q1) ? 1'b1 : 1'b0;

        // noise generator output is use for ptm6840 external clocks (C1, C2, C3)
        noise_shift_reg_95_r <=   noise_shift_reg[95];
        ena_external_clock   <= (!noise_shift_reg_95_r && noise_shift_reg[95]) ? 1'b1 : 1'b0;
    end

    // -------------------------------------------------------------------------
    // Control/Registers Interface With CPU Addr/Data
    // -------------------------------------------------------------------------
    reg  [1:0] ctrl_noise_and_ch1;
    reg  [2:0] ctrl_vol_ch1, ctrl_vol_ch2, ctrl_vol_ch3;

    always @(posedge clock or posedge reset) begin
        if(reset) begin
            ptm6840_ctrl1      <= 8'h1;
            ptm6840_ctrl2      <= 8'h0;
            ptm6840_ctrl3      <= 8'h0;
            ctrl_noise_and_ch1 <= 2'h0;
            ctrl_vol_ch1       <= 3'h0;
            ctrl_vol_ch2       <= 3'h0;
            ctrl_vol_ch3       <= 3'h0;
        end
        else begin
            if(cs) begin
					case(addr[2:0])
							3'b000 	: 	begin
												if (ptm6840_ctrl2[0]) ptm6840_ctrl1 <= di;
												else ptm6840_ctrl3 <= di; 
											end
							3'b001 	:  ptm6840_ctrl2 <= di;                         
							3'b011 	:  ptm6840_max1  <= { ptm6840_msb_buffer, di }; 
							3'b101 	:  ptm6840_max2  <= { ptm6840_msb_buffer, di }; 
							3'b111 	:  ptm6840_max3  <= { ptm6840_msb_buffer, di }; 
							default	:  ptm6840_msb_buffer <= di; 
                endcase
            end
            if (vs) begin
					case(addr[1:0])
							2'b00   	:  ctrl_noise_and_ch1 <= di[1:0]; 
							2'b01   	:  ctrl_vol_ch1       <= di[2:0]; 
							2'b10   	:  ctrl_vol_ch2       <= di[2:0]; 
							default 	:  ctrl_vol_ch3       <= di[2:0]; 
               endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Simplified ptm6840 (Only Useful Part For Berzerk)
    // -------------------------------------------------------------------------
    // only synthesis mode
    // 16 bits count mode only (no dual 8 bits mode)
    // count on internal or external clock
    // no status
    // no IRQ
    // no gates input

    reg signed [8:0] snd1;
    reg signed [8:0] snd2;
    reg signed [8:0] snd3;
    reg        [7:0] vol[0:7];

    initial begin
        vol[0] = 8'h01;
        vol[1] = 8'h02;
        vol[2] = 8'h04;
        vol[3] = 8'h08;
        vol[4] = 8'h10;
        vol[5] = 8'h20;
        vol[6] = 8'h40;
        vol[7] = 8'h80;
    end

    assign sample = ({ snd1,3'b0} + { snd2,3'b0} + {snd3,3'b0});// + 12'h7FF;

    reg        ptm6840_q1_r;
    reg  [7:0] ptm6840_msb_buffer;
    reg [15:0] ptm6840_max1,  ptm6840_max2,  ptm6840_max3;
    reg [15:0] ptm6840_cnt1,  ptm6840_cnt2,  ptm6840_cnt3;
    reg  [7:0] ptm6840_ctrl1, ptm6840_ctrl2, ptm6840_ctrl3;
    reg        ptm6840_q1,    ptm6840_q2,    ptm6840_q3;

    always @(posedge clock or posedge reset) begin
        if(reset) begin
            ptm6840_cnt1 <= ptm6840_max1;
            ptm6840_cnt2 <= ptm6840_max2;
            ptm6840_cnt3 <= ptm6840_max3;
            ptm6840_q1   <= 1'b0;
            ptm6840_q2   <= 1'b0;
            ptm6840_q3   <= 1'b0;
        end
        else begin
            if(!ptm6840_ctrl1[0]) begin
                // Counter #1
                if((ptm6840_ctrl1[1] && ena_internal_clock) || (!ptm6840_ctrl1[1] && ena_external_clock)) begin
                    if(ptm6840_cnt1 == 16'h0000) begin
                        ptm6840_cnt1 <=  ptm6840_max1;
                        ptm6840_q1   <= ~ptm6840_q1;
                    end
                    else begin
                        ptm6840_cnt1 <= ptm6840_cnt1 - 16'd1;
                    end
                end

                // Counter #2
                if((ptm6840_ctrl2[1] && ena_internal_clock) || (!ptm6840_ctrl2[1] && ena_external_clock)) begin
                    if(ptm6840_cnt2 == 16'h0000) begin
                        ptm6840_cnt2 <=  ptm6840_max2;
                        ptm6840_q2   <= ~ptm6840_q2;
                    end
                    else begin
                        ptm6840_cnt2 <= ptm6840_cnt2 - 16'd1;
                    end
                end

                // Counter #3
                if((ptm6840_ctrl3[1] && ena_internal_clock) || (!ptm6840_ctrl3[1] && ena_external_clock)) begin
                    if(ptm6840_cnt3 == 16'h0000) begin
                        ptm6840_cnt3 <=  ptm6840_max3;
                        ptm6840_q3   <= ~ptm6840_q3;
                    end
                    else begin
                        ptm6840_cnt3 <= ptm6840_cnt3 - 16'd1;
                    end
                end
            end
            else begin
                ptm6840_cnt1 <= ptm6840_max1;
                ptm6840_cnt2 <= ptm6840_max2;
                ptm6840_cnt3 <= ptm6840_max3;
            end

            snd1 <= 9'h0;
            snd2 <= 9'h0;
            snd3 <= 9'h0;
            // Channel #1 output is OFF when q1 drive noise generator clock
            if(ptm6840_ctrl1[7]) begin snd1 <= (ptm6840_q1 && !ctrl_noise_and_ch1[1]) ? { 1'b0, vol[ctrl_vol_ch1] } : 9'h0/*-({ 1'b0, vol[ctrl_vol_ch1] })*/; end // FX Channel #1 Enable And Volume
            if(ptm6840_ctrl2[7]) begin snd2 <= (ptm6840_q2)                           ? { 1'b0, vol[ctrl_vol_ch2] } : 9'h0/*-({ 1'b0, vol[ctrl_vol_ch2] })*/; end // FX Channel #2 Enable And Volume
            if(ptm6840_ctrl3[7]) begin snd3 <= (ptm6840_q3)                           ? { 1'b0, vol[ctrl_vol_ch3] } : 9'h0/*-({ 1'b0, vol[ctrl_vol_ch3] })*/; end // FX Channel #2 Enable And Volume
        end
    end

    // -------------------------------------------------------------------------
    // Noise Generator
    // -------------------------------------------------------------------------
    reg [127:0] noise_shift_reg = {128{1'b1}};
    wire        noise_xor = noise_shift_reg[127] ^ noise_shift_reg[95];
    reg         noise_xor_r;

    always @(posedge clock) begin
        if(reset) begin
            noise_shift_reg <= {128{1'b1}};
        end
        else begin
            // noise clock is either same as internal clock or q1 output
            if((!ctrl_noise_and_ch1[0] && ena_internal_clock) ||
               ( ctrl_noise_and_ch1[0] && ena_q1_clock)) begin
                noise_shift_reg <= { noise_shift_reg[126:0], noise_xor_r ^ noise_xor };
                noise_xor_r     <= noise_xor;
            end
        end
    end


endmodule
