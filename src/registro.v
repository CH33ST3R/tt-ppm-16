//------------------------------------------------------------
// registro: registro paralelo de n bits con habilitacion
// Traduccion a Verilog de registro.vhd (PSModule)
// Cambio respecto al VHDL: usa el reloj base y carga D cuando EN = 1
// (EN = Y4CLK), igual que Register3Bits en la v3: un solo reloj.
//------------------------------------------------------------

module registro #(
    parameter integer n = 4
)(
    input  wire         clk,
    input  wire         rst,    // reset asincrono, activo en alto
    input  wire         EN,     // habilitacion: 1 ciclo de cada 4 (Y4CLK)
    input  wire [n-1:0] D,
    output reg  [n-1:0] Q
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            Q <= {n{1'b0}};
        else if (EN)
            Q <= D;
    end

endmodule
