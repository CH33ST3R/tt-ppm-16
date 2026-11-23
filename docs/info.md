## How it works

This tile is the digital part of an IR-UWB transmitter with 16-PPM (pulse position modulation, 16 slots per symbol). Everything runs from the single `clk` input (designed and tested at 10 MHz), and `rst_n` is an asynchronous reset, active low.

The signal chain is:

1. **PN source.** A 24-bit LFSR (x^24 + x^23 + x^22 + x^17 + 1, period 2^24 - 1) with a lock-up detector that injects a `1` after reset.
2. **Probability selector (PSModule).** Four LFSR bits are registered and used as the index into a constant 16-bit vector. `SelP` picks how many ones the vector has, so the information bit `Bitp` is `1` with probability 1/16, 1/8, 1/4 or 1/2. With `SrcExt = 1`, the external input `BitExt` replaces the internal source.
3. **Convolutional encoder.** It has four circuits, selected with `OPsel` and with feedback enabled by `S`:
   - circuits 1 to 3 produce a 4-bit word (`ArrBits`) that sets the pulse position;
   - circuit 4 is a rate 1/2 recursive encoder (feedforward (27,31) octal, feedback (23) octal), and its output appears only on `SLF_z1` and `SLF_z2`. In this mode `ArrBits = 0000`.
4. **4-to-16 decoder and parallel-to-serial register.** The word becomes a 16-slot symbol, which is sent on `TX` one slot per clock, LSB first. `TX_DONE` is high during the last slot (15), and the next symbol is loaded on that clock edge.

`Y4CLK` is a one-cycle pulse every 4 clocks. Its 4th pulse coincides with `TX_DONE`.

The `MODE` input selects when the PSModule register and the encoder advance:

| MODE | Encoder advances on | Result |
|------|------------------|--------|
| 0 | `Y4CLK` (every 4 clocks) | Same behaviour as the version sent to Silicluster v3. Four bits enter per symbol, and the word of the 4th bit is transmitted. |
| 1 | `TX_DONE` (every 16 clocks) | One information bit gives one PPM symbol (rate 1/4 code). |

## How to test

1. Set the clock to 10 MHz, or lower, and pulse `rst_n` low.
2. Select the configuration with the `ui` switches:

| Input | Function |
|-------|----------|
| `SrcExt` | 0 = internal PN source, 1 = `BitExt` |
| `SelP1 SelP0` | 00 = 1/16, 01 = 1/8, 10 = 1/4, 11 = 1/2 |
| `OPsel1 OPsel0` | 00 = circuit 1, 01 = circuit 2, 10 = circuit 3, 11 = circuit 4 (SLF) |
| `S` | 1 = encoder feedback on |
| `MODE` | 0 = Y4CLK rate, 1 = one bit per symbol |

3. Watch `TX` and `TX_DONE` on an oscilloscope or logic analyser. Exactly one pulse should appear in each 16-slot frame, at the slot given by `ArrBits`, except for the first frame after reset, which is empty.
4. Example (`MODE = 0`, `SrcExt = 1`, circuit 1, `S = 1`): reset, then apply `BitExt` = 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, changing it after each `Y4CLK` pulse. Symbols 1 to 4 carry their pulse in slots 14, 0, 6 and 0.
5. With `SrcExt = 0`, count the ones on `Bitpro` at the encoder enable to measure the selected probability.

The cocotb testbench in `test/` compares every output against a cycle-accurate reference model, in both modes.

## External hardware

None. An oscilloscope or logic analyser on the `uo` and `uio[1:0]` pins is enough. An external function generator can be used as the clock.
