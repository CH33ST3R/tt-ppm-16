//------------------------------------------------------------
// aZero: detecta el registro en cero (estado de bloqueo del LFSR)
// Traduccion a Verilog de aZero.vhd (PN_Gen)
// carry = 1 un ciclo despues de ver iData = 0; asi el LFSR arranca
// despues del reset.
//------------------------------------------------------------

module aZero #(
    parameter integer n = 24
)(
    input  wire         CLK,
    input  wire         RST,    // reset asincrono, activo en alto
    input  wire [n-1:0] iData,
    output reg          carry
);

    always @(posedge CLK or posedge RST) begin
        if (RST)
            carry <= 1'b0;
        else
            carry <= (iData == {n{1'b0}});
    end

endmodule
