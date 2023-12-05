// avoid redefincation
`ifndef _include_
`define _include_

// csr regs addr
`define MTVEC    12'h305;
`define MSCRATCH 12'h340;
`define MEPC     12'h341;
`define MCAUSE   12'h342;
`define MSTATUS  12'h300;
`define MIE      12'h304;
`define MIP      12'h344;

// privilege mode
`define U_MODE   2'b00;
`define S_MODE   2'b01;
`define M_MODE   2'b11;

`define DIRECT   2'b0; // set pc to BASE
`define VECTORED 2'b1; // set pc to BASE + 4*cause

`endif