//------------------------------------------------------------
// PPM_16 v5-TT: transmisor 16-PPM completo (top del nucleo)
//
//   PN_Module (LFSR 24) --oRegCo[3:0]--> PSModule --Bitp-->
//   cc_Module_2 --oArrBits--> decoder4_16 --> P2SRegister --> tx
//
// SelP elige la probabilidad de Bitp = 1 (vector SelecP):
//   00 -> 1/16   01 -> 1/8   10 -> 1/4   11 -> 1/2
// SrcExt = 1 usa BitExt (bit externo) en lugar del PN.
// El circuito 4 (OPselector = 11) solo sale por oSLF; en ese modo
// oArrBits = 0000.
//
// MODO (nuevo para Tiny Tapeout) elige cuando avanzan el registro del
// PSModule y el codificador:
//   MODO = 0 -> con Y4CLK (1 ciclo de cada 4), igual que la v5:
//               por simbolo entran 4 bits y se transmite la palabra del 4.o.
//   MODO = 1 -> con tx_done (1 ciclo de cada 16), alineado con la carga
//               del P2S: 1 bit -> 1 simbolo (tasa 1/4, como en el articulo).
// tx_done coincide con el 4.o pulso de Y4CLK, asi que en MODO = 1 el
// codificador avanza justo en los flancos cuyo resultado se transmite.
//------------------------------------------------------------

module PPM_16 (
    input  wire       CLK,         // reloj base
    input  wire       RST,         // reset asincrono, activo en alto
    input  wire       BitExt,      // bit de informacion externo
    input  wire       SrcExt,      // 0 = Bitp del PSModule, 1 = BitExt
    input  wire [1:0] SelP,        // seleccion de probabilidad
    input  wire       S,           // activacion de la retroalimentacion
    input  wire [1:0] OPselector,  // seleccion del codificador
    input  wire       MODO,        // 0 = ritmo Y4CLK (v5), 1 = un bit por simbolo
    output wire       Bitpro,      // bit de probabilidad que entra al codificador
    output wire       Y4CLK,       // 1 ciclo de cada 4 de CLK (siempre, en ambos modos)
    output wire [3:0] oArrBits,    // salida de los circuitos 1, 2 y 3 (va al decoder y al P2S)
    output wire [1:0] oSLF,        // salida del circuito 4 SLF: {z1, z2}
    output wire       tx,          // salida serial PPM (una ranura por ciclo de CLK)
    output wire       tx_done      // en alto durante la ultima ranura de cada simbolo
);

    /* verilator lint_off UNUSEDSIGNAL */
    wire [23:0] oRegCo;    // estado del LFSR de 24 bits (el PSModule usa [3:0])
    /* verilator lint_on UNUSEDSIGNAL */
    reg  [15:0] SelecP;    // vector de probabilidad
    wire        BitpPS;    // bit del PSModule
    wire        Bitp;      // bit que usa el codificador
    wire [15:0] oArr16;    // simbolo PPM de 16 ranuras
    wire        ENcc;      // habilitacion del registro del PS y del codificador

    always @(*) begin
        case (SelP)
            2'b00:   SelecP = 16'b0000000000000001;   // 1/16
            2'b01:   SelecP = 16'b0000000000000011;   // 1/8
            2'b10:   SelecP = 16'b0000000000001111;   // 1/4
            default: SelecP = 16'b0000000011111111;   // 1/2
        endcase
    end

    assign ENcc = MODO ? tx_done : Y4CLK;

    PN_Module #(.n(24)) PN (.CLK(CLK), .RST(RST), .REG(oRegCo));

    PSModule PS2 (
        .RST    (RST),
        .CLK    (CLK),
        .REGa   (oRegCo[3:0]),
        .SelecP (SelecP),
        .EN     (ENcc),
        .Bitp   (BitpPS),
        .Y4CLK  (Y4CLK)
    );

    assign Bitp   = SrcExt ? BitExt : BitpPS;
    assign Bitpro = Bitp;

    cc_Module_2 CC2 (
        .CLK        (CLK),
        .RST        (RST),
        .Bitp       (Bitp),
        .S          (S),
        .OPselector (OPselector),
        .Y4CLK      (ENcc),        // puerto de habilitacion del codificador
        .oReg       (oArrBits),
        .oSLF       (oSLF)
    );

    decoder4_16 DEC (.iArr4(oArrBits), .oArr16(oArr16));

    P2SRegister P2S (
        .CLK          (CLK),
        .RST          (RST),
        .din          (oArr16),
        .tx_done_tick (tx_done),
        .tx           (tx)
    );

endmodule
