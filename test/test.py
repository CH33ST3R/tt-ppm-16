# SPDX-FileCopyrightText: © 2026 Adan Cruz Pena
# SPDX-License-Identifier: Apache-2.0
#
# Testbench de cocotb para tt_um_ch33st3r_ppm16 (transmisor 16-PPM).
#
# Traduccion del testbench autoverificable de la v5 (tb/PPM_16_tb.v):
# un modelo de referencia ciclo a ciclo (PN de 24 bits + PSModule +
# codificador + P2S) se compara en cada flanco de bajada con TODAS las
# salidas: uo_out (oArrBits, z2, z1, tx, tx_done) y uio_out[1:0]
# (Bitpro, Y4CLK). Solo usa los puertos del tile, asi que sirve igual
# para la simulacion RTL y para la de compuertas (GL test).
#
# Pruebas:
#   test_v5_grupos        Modo externo, MODO = 0: las mismas ranuras que la v5.
#   test_modo1_un_bit     Modo externo, MODO = 1: 1 bit -> 1 simbolo.
#   test_probabilidad     Modo interno: P(Bitp = 1) en ambos modos.
#   test_aleatoria        Cambia todas las entradas (incluido MODO) al azar.

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

T_NS = 100  # 10 MHz, igual que la v5


# ----------------------------------------------------------------------
# Modelo de referencia
# ----------------------------------------------------------------------
class Entradas:
    def __init__(self, bitext=0, srcext=1, selp=3, s=0, op=0, modo=0):
        self.bitext, self.srcext, self.selp = bitext, srcext, selp
        self.s, self.op, self.modo = s, op, modo

    def ui(self):
        return (self.bitext | (self.srcext << 1) | (self.selp << 2) |
                (self.s << 4) | (self.op << 5) | (self.modo << 7))


class Modelo:
    UMBRAL = (1, 2, 4, 8)  # k unos en SelecP -> Bitp = 1 cuando REGa < k

    def __init__(self):
        self.reset()

    def reset(self):
        self.pn = 0        # LFSR de 24 bits
        self.carry = 0     # aZero
        self.rega = 0      # registro del PSModule
        self.cnt = 0       # EventCounter4 (Y4CLK cuando cnt = 3)
        self.r3 = 0        # USR3
        self.r4 = 0        # USR4: bit0 = D, bit1 = D^2, bit2 = D^3, bit3 = D^4
        self.n = 0         # ranura del P2S
        self.b = 0         # simbolo en transmision

    @staticmethod
    def _bit(x, i):
        return (x >> i) & 1

    def salidas(self, e):
        """Salidas combinacionales con el estado actual y las entradas e."""
        b = self._bit
        y4 = int(self.cnt == 3)
        tx_done = int(self.n == 15)
        en = tx_done if e.modo else y4
        bitp_ps = int(self.rega < self.UMBRAL[e.selp])
        bitp = e.bitext if e.srcext else bitp_ps
        r3, r4, s = self.r3, self.r4, e.s
        slf = 0
        if e.op == 0:
            rbit = (bitp ^ b(r3, 2) ^ b(r3, 1) ^ b(r3, 0)) if s else bitp
            reg = (r3 << 1) | rbit
        elif e.op == 1:
            rbit = (b(r4, 3) ^ bitp) if s else bitp
            reg = ((rbit ^ b(r4, 2)) << 3) | (b(r4, 0) << 2) | (b(r4, 1) << 1) | b(r4, 3)
        elif e.op == 2:
            rbit = (b(r4, 3) ^ b(r4, 2) ^ bitp) if s else bitp
            reg = (((rbit ^ b(r4, 0)) << 3) | (b(r4, 1) << 2) |
                   ((b(r4, 2) ^ rbit) << 1) | (b(r4, 3) ^ rbit))
        else:
            # Circuito 4 SLF: fb (23)8, ff (27,31)8, escrito con los polinomios
            rbit = (bitp ^ b(r4, 2) ^ b(r4, 3)) if s else bitp
            z1 = rbit ^ b(r4, 1) ^ b(r4, 2) ^ b(r4, 3)
            z2 = rbit ^ b(r4, 0) ^ b(r4, 3)
            slf = (z1 << 1) | z2
            reg = 0
        return dict(y4=y4, tx_done=tx_done, en=en, bitp=bitp, rbit=rbit,
                    reg=reg, slf=slf, tx=self.b & 1)

    def paso(self, e):
        """Flanco de subida de clk con las entradas e."""
        o = self.salidas(e)
        fb = self._bit(self.pn, 0) ^ self._bit(self.pn, 1) ^ self._bit(self.pn, 2) ^ self._bit(self.pn, 7)
        pn_viejo = self.pn
        self.pn = ((self.carry | fb) << 23) | (self.pn >> 1)
        self.carry = int(pn_viejo == 0)
        self.cnt = (self.cnt + 1) & 3
        if o["en"]:
            self.rega = pn_viejo & 0xF
            self.r3 = ((self.r3 << 1) | o["rbit"]) & 0x7
            self.r4 = ((self.r4 << 1) | o["rbit"]) & 0xF
        if self.n == 15:
            self.n = 0
            self.b = 1 << o["reg"]
        else:
            self.n += 1
            self.b >>= 1
        return o

    def uo(self, e):
        o = self.salidas(e)
        return (o["tx_done"] << 7) | (o["tx"] << 6) | (o["slf"] << 4) | o["reg"]

    def uio(self, e):
        o = self.salidas(e)
        return (o["y4"] << 1) | o["bitp"]


# ----------------------------------------------------------------------
# Banco de prueba
# ----------------------------------------------------------------------
class Banco:
    def __init__(self, dut):
        self.dut = dut
        self.m = Modelo()
        self.e = Entradas()
        self.ciclos = 0
        self.fallas = 0
        # Monitor PPM: ranuras con pulso en el simbolo actual
        self.pulsos = []
        self.simbolos = []   # lista de listas de ranuras con pulso

    async def iniciar(self):
        dut = self.dut
        cocotb.start_soon(Clock(dut.clk, T_NS, unit="ns").start())
        dut.ena.value = 1
        dut.uio_in.value = 0
        await self.reiniciar(self.e)

    async def reiniciar(self, e):
        """Reset (rst_n = 0) durante 2 ciclos con las entradas e."""
        dut = self.dut
        await FallingEdge(dut.clk)
        self.e = e
        dut.ui_in.value = e.ui()
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        await FallingEdge(dut.clk)
        dut.rst_n.value = 1
        self.m.reset()
        self.pulsos, self.simbolos = [], []

    def _leer(self, senal):
        v = senal.value
        if not v.is_resolvable:
            return None
        return v.to_unsigned()

    async def ciclo(self, e):
        """Aplica e en el flanco de bajada, espera un ciclo y revisa salidas.

        Devuelve las salidas del modelo en el flanco de subida (o["en"] dice
        si el codificador avanzo en ese flanco).
        """
        dut = self.dut
        self.e = e
        dut.ui_in.value = e.ui()
        o = self.m.paso(e)              # el flanco de subida usa estas entradas
        # Monitor PPM (ranura que se transmitio en este ciclo)
        if o["tx"]:
            self.pulsos.append(self.m.n - 1 if self.m.n else 15)
        if o["tx_done"]:
            self.simbolos.append(self.pulsos)
            self.pulsos = []
        await FallingEdge(dut.clk)
        self.ciclos += 1
        uo, uio, oe = self._leer(dut.uo_out), self._leer(dut.uio_out), self._leer(dut.uio_oe)
        ref_uo, ref_uio = self.m.uo(e), self.m.uio(e)
        if uo != ref_uo or uio is None or (uio & 3) != ref_uio or oe != 0b00000011:
            self.fallas += 1
            if self.fallas <= 10:
                dut._log.error(
                    f"FALLA ciclo {self.ciclos} ui={e.ui():08b} | uo={uo} uio={uio} oe={oe} "
                    f"| ref uo={ref_uo:08b} uio[1:0]={ref_uio:02b}")
        return o

    async def avanzar(self, e):
        """Ciclos hasta el flanco en que el codificador toma el bit (en = 1)."""
        while True:
            o = await self.ciclo(e)
            if o["en"]:
                return o


def ranuras(simbolos):
    """Ranura de cada simbolo (None si no hubo pulso); falla si hay mas de uno."""
    r = []
    for p in simbolos:
        assert len(p) <= 1, f"simbolo con {len(p)} pulsos"
        r.append(p[0] if p else None)
    return r


SEQ = [1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0]  # 1011_0100_0100_0100, igual que la v5

# Ranuras de los simbolos 1 a 4 en la simulacion de la v5 (resultado_simulacion.txt)
V5_ESPERADO = {
    (0, 1): [14, 0, 6, 0],
    (1, 1): [4, 7, 5, 7],
    (2, 1): [10, 1, 3, 13],
    (3, 1): [0, 0, 0, 0],
    (2, 0): [1, 5, 4, 4],
}


async def grupo(tb, op, s, modo):
    """Reset y 16 bits externos; devuelve las ranuras transmitidas."""
    await tb.reiniciar(Entradas(bitext=SEQ[0], srcext=1, s=s, op=op, modo=modo))
    for bit in SEQ:
        await tb.avanzar(Entradas(bitext=bit, srcext=1, s=s, op=op, modo=modo))
    # termina de transmitir el ultimo simbolo cargado
    objetivo = len(tb.simbolos) + 1
    while len(tb.simbolos) < objetivo:
        await tb.ciclo(tb.e)
    return ranuras(tb.simbolos)


@cocotb.test()
async def test_v5_grupos(dut):
    """MODO = 0 reproduce las ranuras de la simulacion de la v5."""
    tb = Banco(dut)
    await tb.iniciar()
    for (op, s), esperado in V5_ESPERADO.items():
        r = await grupo(tb, op, s, modo=0)
        dut._log.info(f"MODO 0  C{op + 1} S={s}: ranuras {r}")
        assert r[0] is None, "el primer simbolo despues del reset debe ir vacio"
        assert r[1:5] == esperado, f"C{op + 1} S={s}: {r[1:5]} != v5 {esperado}"
    assert tb.fallas == 0, f"{tb.fallas} ciclos con salidas distintas al modelo"


@cocotb.test()
async def test_modo1_un_bit(dut):
    """MODO = 1: cada bit produce exactamente un simbolo."""
    tb = Banco(dut)
    await tb.iniciar()
    for (op, s) in V5_ESPERADO:
        r = await grupo(tb, op, s, modo=1)
        dut._log.info(f"MODO 1  C{op + 1} S={s}: ranuras {r}")
        assert r[0] is None
        assert len(r) == 1 + len(SEQ), f"se esperaban {len(SEQ)} simbolos con datos, hubo {len(r) - 1}"
        if op != 3:
            assert all(x is not None for x in r[1:]), "cada simbolo debe llevar un pulso"
    assert tb.fallas == 0, f"{tb.fallas} ciclos con salidas distintas al modelo"


@cocotb.test()
async def test_probabilidad(dut):
    """Fuente interna: P(Bitp = 1) cerca de 1/16, 1/8, 1/4 y 1/2 en ambos modos."""
    tb = Banco(dut)
    await tb.iniciar()
    for modo, nbits in ((0, 2048), (1, 1024)):
        for selp, p_obj in enumerate((1 / 16, 1 / 8, 1 / 4, 1 / 2)):
            e = Entradas(srcext=0, selp=selp, s=1, op=2, modo=modo)
            await tb.reiniciar(e)
            unos = 0
            for _ in range(nbits):
                o = await tb.avanzar(e)
                unos += o["bitp"]
            p = unos / nbits
            dut._log.info(f"MODO {modo} SelP={selp:02b}: objetivo {p_obj:.4f}, medida {unos}/{nbits} = {p:.4f}")
            sigma = (p_obj * (1 - p_obj) / nbits) ** 0.5
            assert abs(p - p_obj) < 5 * sigma, f"probabilidad fuera de rango: {p:.4f}"
    assert tb.fallas == 0, f"{tb.fallas} ciclos con salidas distintas al modelo"


@cocotb.test()
async def test_aleatoria(dut):
    """Todas las entradas al azar (incluido MODO), revisando cada ciclo."""
    rnd = random.Random(2026)
    tb = Banco(dut)
    await tb.iniciar()
    e = Entradas()
    for k in range(12000):
        if k % 96 == 0:
            e = Entradas(srcext=rnd.getrandbits(1), selp=rnd.getrandbits(2),
                         s=int(rnd.random() < 0.75), op=rnd.getrandbits(2),
                         modo=rnd.getrandbits(1))
        if k % 2000 == 1000:
            await tb.reiniciar(e)
        e = Entradas(bitext=rnd.getrandbits(1), srcext=e.srcext, selp=e.selp,
                     s=e.s, op=e.op, modo=e.modo)
        await tb.ciclo(e)
    dut._log.info(f"{tb.ciclos} ciclos revisados")
    assert tb.fallas == 0, f"{tb.fallas} ciclos con salidas distintas al modelo"
