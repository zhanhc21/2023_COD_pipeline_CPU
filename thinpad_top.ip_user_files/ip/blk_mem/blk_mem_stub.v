// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Mon Dec 11 21:36:08 2023
// Host        : LAPTOP-5KO6II7D running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top blk_mem -prefix
//               blk_mem_ blk_mem_stub.v
// Design      : blk_mem
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg676-2L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module blk_mem(clka, ena, wea, addra, dina, clkb, enb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[1:0],addra[10:0],dina[15:0],clkb,enb,addrb[10:0],doutb[15:0]" */;
  input clka;
  input ena;
  input [1:0]wea;
  input [10:0]addra;
  input [15:0]dina;
  input clkb;
  input enb;
  input [10:0]addrb;
  output [15:0]doutb;
endmodule
