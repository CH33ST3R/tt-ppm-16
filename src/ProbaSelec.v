//------------------------------------------------------------
// ProbaSelec: multiplexor 16 a 1 (seleccion de probabilidad)
// Traduccion a Verilog de ProbaSelec.vhd (PSModule)
// oBit = iMux[iselecR]. Si iMux tiene k unos, P(oBit = 1) = k/16.
//------------------------------------------------------------

module ProbaSelec #(
    parameter integer n = 16
)(
    input  wire [n-1:0] iMux,      // vector de probabilidad (SelecP)
    input  wire [3:0]   iselecR,   // numero pseudoaleatorio 0..15
    output wire         oBit
);

    assign oBit = iMux[iselecR];

endmodule
