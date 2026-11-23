//------------------------------------------------------------
// P2SRegister: registro paralelo a serie de 16 ranuras
// Saca din bit por bit (LSB primero, una ranura por ciclo de CLK)
// y en la ultima ranura carga el siguiente simbolo.
//------------------------------------------------------------

module P2SRegister (
    input  wire        CLK,           // reloj base (una ranura por ciclo)
    input  wire        RST,           // reset asincrono, activo en alto
    input  wire [15:0] din,           // simbolo PPM a transmitir
    output wire        tx_done_tick,  // '1' durante la ultima ranura (15)
    output wire        tx             // salida serial PPM
);

    reg [3:0]  n_reg;   // ranura actual (0..15)
    reg [15:0] b_reg;   // simbolo en transmision

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            n_reg <= 4'd0;
            b_reg <= 16'd0;
        end else if (n_reg == 4'd15) begin
            n_reg <= 4'd0;
            b_reg <= din;                    // carga del siguiente simbolo
        end else begin
            n_reg <= n_reg + 4'd1;
            b_reg <= {1'b0, b_reg[15:1]};    // corrimiento a la derecha
        end
    end

    assign tx           = b_reg[0];
    assign tx_done_tick = (n_reg == 4'd15);

endmodule
