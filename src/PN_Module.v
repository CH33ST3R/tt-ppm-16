//------------------------------------------------------------
// PN_Module: generador de numeros pseudoaleatorios (LFSR de 24 bits)
// Traduccion a Verilog de PN_Module.vhd (PN_Gen)
//
// Tomas corregidas: bits 0, 1, 2 y 7 -> x^24 + x^23 + x^22 + x^17 + 1
// (periodo maximo 2^24 - 1). En el VHDL original eran 16, 21, 22, 23,
// que solo usan los 8 bits mas nuevos y dan un periodo de 217 ciclos.
//------------------------------------------------------------

module PN_Module #(
    parameter integer n = 24
)(
    input  wire         CLK,
    input  wire         RST,    // reset asincrono, activo en alto
    output wire [n-1:0] REG     // estado del LFSR (el PSModule usa REG[3:0])
);

    wire [n-1:0] oREG;
    wire         carry, retrobit, rA;

    ShiftRegister #(.n(n)) SREG (.Aclr(RST), .Clk(CLK), .OReg(oREG), .R(rA));
    aZero         #(.n(n)) aZ   (.CLK(CLK), .RST(RST), .iData(oREG), .carry(carry));

    assign retrobit = oREG[0] ^ oREG[1] ^ oREG[2] ^ oREG[7];
    assign rA       = carry | retrobit;
    assign REG      = oREG;

endmodule
