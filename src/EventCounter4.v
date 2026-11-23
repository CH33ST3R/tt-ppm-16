//------------------------------------------------------------
// EventCounter4: genera Y4CLK (clk4) a partir del reloj base CLK
// Traduccion a Verilog de EventCounter4.vhd (arquitectura moore)
//
// FSM de Moore de 4 estados: S_0 -> S_1 -> S_2 -> S_3 -> S_0 ...
// Y = 1 solo en S_3: un pulso de 1 ciclo de CLK cada 4 ciclos.
// Reset asincrono, activo en alto.
//
// Los estados se codifican en Gray (00,01,11,10): en cada
// transicion cambia un solo bit, asi Y no tiene glitches.
//------------------------------------------------------------

module EventCounter4 (
    input  wire RST,
    input  wire CLK,
    output reg  Y
);

    localparam [1:0] S_0 = 2'b00,
                     S_1 = 2'b01,
                     S_2 = 2'b11,
                     S_3 = 2'b10;

    reg [1:0] P_S, N_S;   // estado presente / estado siguiente

    // Proceso combinacional: estado siguiente y salida
    always @(*) begin
        case (P_S)
            S_0:     begin Y = 1'b0; N_S = S_1; end
            S_1:     begin Y = 1'b0; N_S = S_2; end
            S_2:     begin Y = 1'b0; N_S = S_3; end
            S_3:     begin Y = 1'b1; N_S = S_0; end
            default: begin Y = 1'b0; N_S = S_0; end
        endcase
    end

    // Proceso secuencial
    always @(posedge CLK or posedge RST) begin
        if (RST) P_S <= S_0;
        else     P_S <= N_S;
    end

endmodule
