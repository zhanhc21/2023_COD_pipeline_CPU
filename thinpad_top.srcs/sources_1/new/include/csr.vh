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

// exception or interrupt
`define INTERRUPT 1'b1
`define EXCEPTION 1'b0

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

// interrupt code
`define MACHINE_TIMER_INTERRUPT 31'd7

// instr type enum
typedef enum logic [4:0] {
    ADD   = 0,
    ADDI  = 1,
    AND   = 2,
    ANDI  = 3,
    AUIPC = 4,
    BEQ   = 5,
    BNE   = 6,
    JAL   = 7,
    JALR  = 8,
    LB    = 9,
    LUI   = 10,
    LW    = 11,
    OR    = 12,
    ORI   = 13,
    SB    = 14,
    SLLI  = 15,
    SRLI  = 16,
    SW    = 17,
    XOR   = 18,
    ANDN  = 19,
    SBSET = 20,
    MINU  = 21,
    NOP   = 22,
    CSRRC = 23,
    CSRRS = 24,
    CSRRW = 25,
    SLTU  = 26,
    EBREAK = 27,
    ECALL = 28,
    MRET  = 29
} op_type;


// ID stage enum
typedef enum logic [6:0] {
    OPCODE_ADD_AND_OR_XOR_ANDN_SBSET_MINU_SLTU = 7'b0110011,
    OPCODE_ADDI_ANDI_ORI_SLLI_SRLI = 7'b0010011,
    OPCODE_AUIPC = 7'b0010111,
    OPCODE_BEQ_BNE = 7'b1100011,
    OPCODE_JAL = 7'b1101111,
    OPCODE_JALR = 7'b1100111,
    OPCODE_LB_LW = 7'b0000011,
    OPCODE_LUI = 7'b0110111,
    OPCODE_SB_SW = 7'b0100011,
    OPCODE_CSRRC_CSRRS_CSRRW_EBREAK_ECALL_MRET = 7'b1110011
} opcode_t;

typedef enum logic [2:0] {
    TYPE_R = 0,
    TYPE_I = 1,
    TYPE_S = 2,
    TYPE_B = 3,
    TYPE_U = 4,
    TYPE_J = 5
} inst_type_t;

typedef enum logic [3:0] {
    ALU_DEFAULT = 4'd0,
    ALU_ADD = 4'd1,
    ALU_SUB = 4'd2,
    ALU_AND = 4'd3,
    ALU_OR = 4'd4,
    ALU_XOR = 4'd5,
    ALU_NOT = 4'd6,
    ALU_SLL = 4'd7,
    ALU_SRL = 4'd8,
    ALU_SRA = 4'd9,
    ALU_ROL = 4'd10,
    ALU_ANDN = 4'd11,
    ALU_SBSET = 4'd12,
    ALU_MINU = 4'd13,
    ALU_SLTU = 4'd14
} alu_op_type_t;

`endif