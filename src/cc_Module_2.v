//------------------------------------------------------------
//--- Codificador Convolucional (Verilog) --------------------
//------------------------------------------------------------
// Traduccion a Verilog de cc_Module_2.vhd
//
//  - Y4CLK (clk4) llega desde el top PPM_16 (EventCounter4) y se
//    usa como habilitacion de USR3/USR4: los registros avanzan una
//    vez cada 4 ciclos de CLK.
//  - oReg: salida de 4 bits de los circuitos 1, 2 y 3. Es la misma
//    palabra que va al decoder4_16 y al P2SRegister.
//  - oSLF: salida propia del circuito 4 SLF, {z1, z2}. El circuito 4
//    solo sale por aqui; no pasa a oReg.
//
//  OPselector = 00 -> Circuito 1   oReg = salida del circuito 1, oSLF = 00
//               01 -> Circuito 2   oReg = salida del circuito 2, oSLF = 00
//               10 -> Circuito 3   oReg = salida del circuito 3, oSLF = 00
//               11 -> Circuito 4   oReg = 0000,                  oSLF = {z1, z2}
//------------------------------------------------------------

module cc_Module_2 (
    input  wire        CLK,         // reloj base
    input  wire        RST,         // reset asincrono, activo en alto
    input  wire        Bitp,        // bit de informacion
    input  wire        S,           // activacion de la retroalimentacion
    input  wire [1:0]  OPselector,  // seleccion del circuito
    input  wire        Y4CLK,       // clk4 del EventCounter4: 1 ciclo de cada 4 de CLK
    output wire [3:0]  oReg,        // salida del codificador (posicion del pulso)
    output wire [1:0]  oSLF         // salida del circuito 4 SLF: {z1, z2}
);

    wire [2:0] oReg3;   // registro de 3 casillas
    wire [3:0] oReg4;   // registro de 4 casillas
    reg        rbit;    // bit de entrada a los registros (con retroalimentacion)
    reg  [3:0] rReg;    // salida de los circuitos
    reg  [1:0] rSLF;    // salida del circuito 4

    // Registros de corrimiento a la izquierda de 3 y 4 bits
    Register3Bits #(.n(3)) USR3 (.RST(RST), .Clk(CLK), .EN(Y4CLK), .OReg(oReg3), .L(rbit));
    Register3Bits #(.n(4)) USR4 (.RST(RST), .Clk(CLK), .EN(Y4CLK), .OReg(oReg4), .L(rbit));

    assign oReg = rReg;
    assign oSLF = rSLF;

    // Seleccion del tipo de retroalimentacion
    always @(*) begin
        rSLF = 2'b00;
        case (OPselector)
            2'b00: begin   // Circuito 1
                rbit = S ? (Bitp ^ oReg3[2] ^ oReg3[1] ^ oReg3[0]) : Bitp;
                rReg = {oReg3, rbit};
            end
            2'b01: begin   // Circuito 2
                rbit = S ? (oReg4[3] ^ Bitp) : Bitp;
                rReg = {rbit ^ oReg4[2], oReg4[0], oReg4[1], oReg4[3]};
            end
            2'b10: begin   // Circuito 3
                rbit = S ? (oReg4[3] ^ oReg4[2] ^ Bitp) : Bitp;
                rReg = {rbit ^ oReg4[0], oReg4[1], oReg4[2] ^ rbit, oReg4[3] ^ rbit};
            end
            default: begin // 2'b11: Circuito 4, SLS-CE tasa 1/2, ff (27,31)8 y fb (23)8
                // oReg4[0]=D, oReg4[1]=D^2, oReg4[2]=D^3, oReg4[3]=D^4
                rbit = S ? (Bitp ^ oReg4[2] ^ oReg4[3]) : Bitp;             // w  = y + D^3 + D^4
                rSLF = {rbit ^ oReg4[1] ^ oReg4[2] ^ oReg4[3],              // z1 = w + D^2 + D^3 + D^4
                        rbit ^ oReg4[0] ^ oReg4[3]};                        // z2 = w + D + D^4
                rReg = 4'b0000;                                             // el circuito 4 solo sale por oSLF
            end
        endcase
    end

endmodule
