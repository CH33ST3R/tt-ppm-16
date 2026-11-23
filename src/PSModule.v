//------------------------------------------------------------
// PSModule: probabilidades de la fuente de informacion
// Traduccion a Verilog de PSModule.vhd
//   EventCounter4 -> Y4CLK (1 ciclo de cada 4 de CLK)
//   registro      -> captura REGa (4 bits del PN) cuando EN = 1
//   ProbaSelec    -> Bitp = SelecP[registro]
// El vector se llama SelecP (en el VHDL era S) para no confundirlo
// con la entrada S (retroalimentacion) de cc_Module_2.
//
// Cambio para Tiny Tapeout: el registro usa la entrada EN en lugar de
// Y4CLK, para que el top elija el ritmo (Y4CLK o tx_done, pin MODO).
//------------------------------------------------------------

module PSModule #(
    parameter integer n = 16
)(
    input  wire         RST,     // reset asincrono, activo en alto
    input  wire         CLK,
    input  wire [3:0]   REGa,    // 4 bits del PN_Module
    input  wire [n-1:0] SelecP,  // vector de probabilidad
    input  wire         EN,      // habilitacion del registro (Y4CLK o tx_done)
    output wire         Bitp,    // bit de informacion
    output wire         Y4CLK    // 1 ciclo de cada 4 de CLK
);

    wire [3:0] oReg3b;           // numero pseudoaleatorio registrado

    EventCounter4    EV3 (.RST(RST), .CLK(CLK), .Y(Y4CLK));
    registro #(.n(4)) REG (.clk(CLK), .rst(RST), .EN(EN), .D(REGa), .Q(oReg3b));
    ProbaSelec #(.n(n)) PS (.iMux(SelecP), .iselecR(oReg3b), .oBit(Bitp));

endmodule
