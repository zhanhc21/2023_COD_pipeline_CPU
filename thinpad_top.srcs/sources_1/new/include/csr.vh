// avoid redefincation
`ifndef _include_
`define _include_

// csr regs addr
`define MTVEC    12'h305
`define MSCRATCH 12'h340
`define MEPC     12'h341
`define MCAUSE   12'h342
`define MSTATUS  12'h300
`define MIE      12'h304
`define MIP      12'h344

// privilege mode
`define U_MODE   2'b00
`define S_MODE   2'b01
`define M_MODE   2'b11

// trap vector mode
`define DIRECT   2'b0 // set pc to BASE
`define VECTORED 2'b1 // set pc to BASE + 4*cause

// exc code
`define INSTR_ADDR_MISALIGNED   31'd0
`define INSTR_ACCESS_FAULT      31'd1
`define ILLEGAL_INSTR           31'd2
`define EBREAK                  31'd3
`define ECALL_U                 31'd8
`define ECALL_S                 31'd9
`define ECALL_M                 31'd11
`define INSTR_PAGE_FAULT        31'd12
`define NOP                     31'd16

`endif