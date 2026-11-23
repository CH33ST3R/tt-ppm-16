//------------------------------------------------------------
// Register3Bits: registro de corrimiento a la izquierda de n bits
// Traduccion a Verilog de Register3Bits.vhd
//
// Cambio: ahora usa el reloj base Clk y solo corre cuando EN=1
// (EN = Y4CLK del EventCounter4). Asi todo el codificador
// trabaja con un solo reloj, como se recomienda para silicio.
//------------------------------------------------------------

module Register3Bits #(
    parameter integer n = 3
)(
    input  wire         RST,    // reset asincrono, activo en alto
    input  wire         Clk,    // reloj base
    input  wire         EN,     // habilitacion: 1 ciclo de cada 4 (Y4CLK)
    output wire [n-1:0] OReg,
    input  wire         L       // bit de entrada al registro de corrimiento
);

    reg [n-1:0] P_S;            // estado presente

    // estado siguiente: corrimiento hacia la izquierda, L entra por el LSB
    wire [n-1:0] N_S = {P_S[n-2:0], L};

    always @(posedge Clk or posedge RST) begin
        if (RST)
            P_S <= {n{1'b0}};
        else if (EN)
            P_S <= N_S;
    end

    assign OReg = P_S;

endmodule
