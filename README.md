![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Transmisor IR-UWB 16-PPM con codificador convolucional — Tiny Tapeout GF26c

Proyecto para la convocatoria **IEEE Open Silicon** (Tiny Tapeout, shuttle GlobalFoundries GF180, TTGF26c).
Es la adaptación a Tiny Tapeout del transmisor `PPM_16` v5 enviado a Silicluster v3, con un pin nuevo de modo (`ui[7]`).

- Hoja de datos del proyecto: [docs/info.md](docs/info.md)
- Top del tile: `tt_um_ch33st3r_ppm16` (`src/project.v`), 1x1, reloj de 10 MHz.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/project.v` | Envoltura de Tiny Tapeout: pines `ui/uo/uio`, `rst_n` (activo en bajo) → `RST` |
| `src/PPM_16.v` | Top del núcleo: PN + PSModule + mux SrcExt + codificador + decoder + P2S, y selector `MODO` |
| `src/PN_Module.v`, `ShiftRegister.v`, `aZero.v` | LFSR de 24 bits (tomas 0, 1, 2, 7) |
| `src/PSModule.v`, `EventCounter4.v`, `registro.v`, `ProbaSelec.v` | Fuente con probabilidad seleccionable y `Y4CLK` |
| `src/cc_Module_2.v`, `Register3Bits.v` | Codificador convolucional (circuitos 1 a 4) |
| `src/decoder4_16.v`, `P2SRegister.v` | Símbolo de 16 ranuras y salida serial |
| `test/test.py` | Testbench de cocotb con modelo de referencia ciclo a ciclo (RTL y GL) |

Con varios archivos, cada `.v` va en `src/` y se lista uno por renglón en `source_files` de `info.yaml` y en `PROJECT_SOURCES` de `test/Makefile`.

## Pines

| Pin | Señal | | Pin | Señal |
|---|---|---|---|---|
| ui[0] | BitExt | | uo[3:0] | oArrBits[3:0] |
| ui[1] | SrcExt | | uo[4] | oSLF[0] (z2) |
| ui[3:2] | SelP[1:0] | | uo[5] | oSLF[1] (z1) |
| ui[4] | S | | uo[6] | tx |
| ui[6:5] | OPselector[1:0] | | uo[7] | tx_done |
| ui[7] | MODO | | uio[0] | Bitpro (salida) |
| | | | uio[1] | Y4CLK (salida) |

`MODO = 0`: el codificador avanza con Y4CLK (1 de cada 4 ciclos), igual que la v5.
`MODO = 1`: avanza con tx_done (1 de cada 16 ciclos), así que 1 bit produce 1 símbolo.

## Simulación local

```sh
cd test
make -B            # RTL
```

Debe terminar con `TESTS=4 PASS=4 FAIL=0`. Con `MODO = 0` el test reproduce las ranuras de la simulación de la v5 (C1: 14, 0, 6, 0; C2: 4, 7, 5, 7; C3: 10, 1, 3, 13; C4: 0, 0, 0, 0; C3 sin retroalimentación: 1, 5, 4, 4).
