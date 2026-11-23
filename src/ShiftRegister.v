//------------------------------------------------------------
// ShiftRegister: registro de corrimiento a la derecha de n bits
// Traduccion a Verilog de ShiftRegister.vhd (PN_Gen)
// El bit R entra por el MSB (bit n-1); el bit 0 es el mas viejo.
//------------------------------------------------------------

module ShiftRegister #(
    parameter integer n = 24
)(
    input  wire         Aclr,   // reset asincrono, activo en alto
    input  wire         Clk,
    output wire [n-1:0] OReg,
    input  wire         R       // bit de entrada al registro de corrimiento
);

    reg [n-1:0] P_S;            // estado presente

    always @(posedge Clk or posedge Aclr) begin
        if (Aclr)
            P_S <= {n{1'b0}};
        else
            P_S <= {R, P_S[n-1:1]};     // hacia la derecha
    end

    assign OReg = P_S;

endmodule
