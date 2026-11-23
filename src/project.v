/*
 * Copyright (c) 2026 Adan Cruz Pena
 * SPDX-License-Identifier: Apache-2.0
 *
 * Envoltura de Tiny Tapeout para el transmisor IR-UWB 16-PPM (PPM_16).
 *
 * Entradas (ui_in):
 *   ui[0] BitExt      bit de informacion externo
 *   ui[1] SrcExt      0 = fuente interna (PN + PSModule), 1 = BitExt
 *   ui[2] SelP[0]     probabilidad de Bitp = 1:
 *   ui[3] SelP[1]       00 = 1/16, 01 = 1/8, 10 = 1/4, 11 = 1/2
 *   ui[4] S           activa la retroalimentacion del codificador
 *   ui[5] OPsel[0]    circuito: 00 = C1, 01 = C2, 10 = C3, 11 = C4 (SLF)
 *   ui[6] OPsel[1]
 *   ui[7] MODO        0 = el codificador avanza con Y4CLK (como la v5)
 *                     1 = avanza con tx_done (1 bit por simbolo)
 * Salidas (uo_out):
 *   uo[3:0] oArrBits  palabra de los circuitos 1 a 3 (ranura del pulso)
 *   uo[4]   z2        oSLF[0], circuito 4
 *   uo[5]   z1        oSLF[1], circuito 4
 *   uo[6]   tx        salida serial 16-PPM (una ranura por ciclo de clk)
 *   uo[7]   tx_done   en alto en la ultima ranura (15) de cada simbolo
 * Bidireccionales (siempre como salida en uio[1:0]):
 *   uio[0]  Bitpro    bit que entra al codificador
 *   uio[1]  Y4CLK     pulso de 1 ciclo de cada 4
 *   uio[7:2] sin uso (configurados como entradas)
 *
 * rst_n de Tiny Tapeout es activo en bajo; el nucleo usa RST activo en alto.
 */

`default_nettype none

module tt_um_ch33st3r_ppm16 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [3:0] oArrBits;
  wire [1:0] oSLF;
  wire       Bitpro, Y4CLK, tx, tx_done;

  PPM_16 core (
      .CLK        (clk),
      .RST        (~rst_n),
      .BitExt     (ui_in[0]),
      .SrcExt     (ui_in[1]),
      .SelP       (ui_in[3:2]),
      .S          (ui_in[4]),
      .OPselector (ui_in[6:5]),
      .MODO       (ui_in[7]),
      .Bitpro     (Bitpro),
      .Y4CLK      (Y4CLK),
      .oArrBits   (oArrBits),
      .oSLF       (oSLF),
      .tx         (tx),
      .tx_done    (tx_done)
  );

  assign uo_out  = {tx_done, tx, oSLF, oArrBits};
  assign uio_out = {6'b000000, Y4CLK, Bitpro};
  assign uio_oe  = 8'b00000011;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in, 1'b0};

endmodule
