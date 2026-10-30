# Phase-Domain Z3: First Experiment and Buy List

| Field | Value |
|---|---|
| Source model | Grok 4.7, raw draft `grok-phase-hw.md` |
| Date | 2026-09-29 |
| Verification status | Math VERIFIED (re-derived and checked by a C Monte Carlo). Hardware table PARTIALLY VERIFIED (8 products checked on the web, 3 not checked). |
| What was checked | Z3 add as phasor multiplication; the plus/minus 60 degree decision cells; the exact 3-PSK symbol error formula and its erfc approximation at 0 to 12 dB; the correlator SNR relation; jitter, cable and quantization numbers; prices and key specs of RFSoC 4x2, STEMlab 125-14, ADALM-PLUTO, USRP B210, ADALM2000, ULX3S (12F and 85F), Pmod DA4. |
| What was corrected | (1) The raw draft had a summary paragraph spliced into the middle of Section 1, cutting off part of the signal-level text; repaired below. (2) Grok's error table is for one noisy phasor, but an add multiplies two noisy phasors; the add is about 2 dB worse (added below, with Monte Carlo numbers). (3) ADALM-PLUTO price was wrong ($399.99; real list is about $215 to $280). (4) STEMlab 125-14 price was the PRO tier; the base starter kit is cheaper. (5) Pmod DA4 has 8 DAC channels, not 2. |
| Monte Carlo program | `~/.claude/jobs/c8884ded/tmp/verify/z3mc.c` (C, xoshiro-style RNG, Box-Muller noise). Not in the repo. |

Prices are USD list or reseller snapshots as of 2026-09-29. Anything still uncertain is marked **verify**.

Pass condition: for all 9 input pairs, decoded trit equals `(a+b) mod 3`, 1000 trials each, zero mismatches. Speed, energy and latency come after that gate.

## 1. Experiment

### The map

Z3 = {0, 1, 2} under addition mod 3. Encode k as the cube root of unity

```
w^k = exp(j 2 pi k / 3)     phases {0, 120, 240 degrees}
w^a * w^b = exp(j 2 pi (a+b) / 3) = w^((a+b) mod 3)
```

because `w^3 = 1`. Multiplying phasors adds phases, and phase addition mod 360 degrees is Z3 addition. **VERIFIED** (algebra, and the C program checks all 9 pairs with a 32-bit phase word: 0 mismatches).

In digital form, a 32-bit phase word does the same thing with a wrapping integer add: one third of a turn is `2^32 / 3 = 1431655765` (the remainder of 1/3 LSB is harmless because decisions are 60 degrees wide), and one LSB is `360 / 2^32 = 8.4e-8` degrees. That adder is exactly a numerically controlled oscillator (NCO) phase accumulator. In analog form, a mixer does it: the product of two tones has a component at `2 f_c` whose phase is `phi_a + phi_b`.

### Signal plan (repaired from the spliced paragraph)

- Reference design: 125 MS/s loopback, `f_c = f_s / 64 = 1.953125 MHz`, N = 4096 samples (64 cycles, 32.768 microseconds).
- Tone amplitude at half of full-scale peak (-6.02 dB versus a full-scale sine), so two equal tones summed in analog reach full scale and do not clip. With a bipolar 14-bit converter, peak code 8191, tone peak about 4096 codes.
- Ideal full-scale sine SQNR is `6.02 B + 1.76` dB. At half amplitude, 14-bit ideal is `6.02 x 13 + 1.76 = 80.0 dB`, so `SNR_1 = (A^2/2) / sigma^2 = 1.0e8` per sample. At 11 effective bits and the same backoff, about 62 dB. Measure the effective bits on the board you use.
- One sample of timing slip at `f_s / 64` is `360 / 64 = 5.625` degrees. **VERIFIED.**
- Low-rate open-toolchain version: 1 MS/s, same ratio `f_c = f_s / 64` (15.6 kHz), N = 1024 (16 cycles, 1.024 ms).

### Decision rule and error rate

Each symbol owns a cell of plus/minus 60 degrees around its phase. Decode `k_hat = mod(round(theta / (2 pi / 3)), 3)`. An error is `|delta theta| > 60 degrees`.

One complex sample, amplitude A, noise variance `sigma^2` per axis, `N_0 = 2 sigma^2`, symbol SNR `rho = A^2 / N_0`. For small noise, phase noise is

```
sigma_phi^2 = sigma^2 / A^2 = 1 / (2 rho)      sigma_phi = 1 / sqrt(2 rho) radians
```

Exact coherent 3-PSK symbol error (Craig's form, with `sin^2(pi/3) = 3/4`):

```
P_err = (1/pi) * integral from 0 to 2pi/3 of exp(-rho * (3/4) / sin^2(theta)) d theta
P_err ~ erfc( sqrt(rho) * sqrt(3) / 2 )      (two-neighbor bound; a bit high at low SNR)
```

Both formulas **VERIFIED** (standard M-PSK result with M = 3; the approximation equals `2 Q(sqrt(2 rho) sin(pi/3))`). Monte Carlo check, one noisy phasor, decoded against its own symbol:

| rho (dB) | sigma_phi | Monte Carlo | exact (Craig) | erfc approx | Grok's table (exact) |
|---|---|---|---|---|---|
| 0 | 40.5 deg | 1.835e-1 | 1.834e-1 | 2.207e-1 | 1.83e-1 |
| 6 | 20.3 deg | 1.363e-2 | 1.371e-2 | 1.454e-2 | 1.37e-2 |
| 8 | 16.1 deg | 2.029e-3 | 2.037e-3 | 2.095e-3 | 2.04e-3 |
| 10 | 12.8 deg | 1.055e-4 (5e7 trials) | 1.065e-4 | 1.075e-4 | 1.07e-4 |
| 12 | 10.2 deg | 1.17e-6 (4e8 trials, about 470 errors) | 1.082e-6 | 1.084e-6 | 1.08e-6 |

Grok's rows at 14 and 16 dB (8.34e-10, 1.10e-14) were not simulated (too rare to count); they follow the same formula. Grok's thresholds (1e-3 at 8.57 dB, 1e-6 at 12.03 dB, 1e-9 at 13.96 dB, 1e-12 at 15.30 dB) are consistent with the verified formula.

**[added] Correction: the add uses two noisy phasors.** The table above is for reading one phasor. A Z3 add multiplies two phasors, and each carries its own noise, so phase noise variance doubles at high SNR. Monte Carlo of the actual add, both inputs at the same rho, decoded against `(a+b) mod 3`:

| rho per input (dB) | Monte Carlo, add | single-phasor exact |
|---|---|---|
| 0 | 3.52e-1 | 1.83e-1 |
| 6 | 5.76e-2 | 1.37e-2 |
| 8 | 1.52e-2 | 2.04e-3 |
| 10 | 1.96e-3 | 1.07e-4 |
| 12 | 8.46e-5 | 1.08e-6 |

Rule of thumb: the add needs roughly 2 to 3 dB more SNR per input than one symbol read. This does not change any conclusion below, because the operating point is 80 to 100 dB past these contours.

### Correlator gain

With N real samples and per-sample `SNR_1 = (A^2/2) / sigma^2`, correlating against the known tone gives radius `A N / 2` and noise variance `N sigma^2 / 2` per axis, so `sigma_phi^2 = 1 / (N SNR_1)`. Matching `1 / (2 rho)`:

```
rho = N * SNR_1 / 2
```

**VERIFIED.** Ideal 14-bit, -6 dBFS, N = 4096: `rho = 4096 x 1.0e8 / 2 = 2.06e11` (113.1 dB), `sigma_phi = 8.9e-5` degrees. That is about 98 dB beyond the point where a single read errs once in 10^12, and about 95 dB beyond it for the two-phasor add. Random noise errors in 9000 trials are not observable. Any mismatch means a wrap bug, a slipped sample index, a bad cable, or a fixed phase bias close to 60 degrees. A fixed bias beta shrinks the cell edge to `60 - |beta|` degrees.

### Phase jitter

Timing jitter converts to phase as `sigma_phi = 2 pi f_c sigma_t`. At 1.953125 MHz, 1 degree rms corresponds to `sigma_t = 1 / (360 f_c) = 1.422 ns`; a 1 ps aperture jitter is 0.0007 degrees. **VERIFIED.**

**[added]** Error rate of the add under pure Gaussian phase jitter `sigma_j` on each input (independent): `P_err = 2 Q(60 / (sqrt(2) sigma_j))`, degrees. Monte Carlo check (2e7 trials each):

| sigma_j per input | Monte Carlo | formula |
|---|---|---|
| 10 deg | 2.22e-5 | 2.21e-5 |
| 15 deg | 4.69e-3 | 4.68e-3 |
| 20 deg | 3.39e-2 | 3.39e-2 |
| 25 deg | 8.97e-2 | 8.97e-2 |

For a chain of L adds with independent errors, phase error grows as `sigma_1 sqrt(L)`.

### Timing and calibration

Share one sample index for both channels so designed digital slip is zero. Residual analog delay tau appears as phase `360 f_c tau`. Staying under 5 degrees needs `tau < 7.11 ns`. One metre of cable at velocity factor 0.70 is 4.77 ns, which is 3.35 degrees at this carrier (**VERIFIED**). Absorb it in a per-channel offset `delta_i`. Cable tempco of 100 ppm/degC gives about 3.4e-4 degrees per degC per metre here (planning figure; measure filter drift on the board).

One oscillator and one PLL feed both NCOs and the ADC clock. Clear both NCOs on the same cycle.

Before each 9 x 1000 block:
1. Emit k = 0 on each channel, store `delta_i = theta_i`.
2. Emit k = 1. Require `theta - delta_i` within 120 +/- 5 degrees, else stop (scale, wiring, stuck NCO).
3. Rotate later phasors by `exp(-j delta_i)` before multiplying.
4. If board temperature moves more than 2 degC during the block, discard and repeat. Log `delta_i` and temperature.

Correlator at the known frequency bin, N = 4096:

```
I = sum x[n] cos(2 pi n / 64)
Q = sum x[n] (-sin(2 pi n / 64))
```

Multiply `(Ia + j Qa)(Ib + j Qb)`, one `atan2`. Flags fail the trial (no majority voting):
- Magnitude under 0.3x the k = 0 magnitude on that channel: erasure.
- Product phase more than 30 degrees from the nearest center: reject.
- Later, with no integer oracle: send `c = (-(a+b)) mod 3` and require `a + b + c = 0 mod 3`.

Pass: 9 x 1000, zero mismatches. Print the wrap pairs `(1,2) -> 0`, `(2,1) -> 0`, `(2,2) -> 1` on their own lines.

### After the gate

- Repeatability: spread of product phase over 1000 repeats of (1,1), again after one hour with `delta_i` frozen.
- Drift: `delta_i` versus board temperature.
- Latency: trigger index to decode index times `1 / f_s` (pipeline); host wall time over USB or Ethernet reported separately.
- Energy: `(P_run - P_idle) x T` joules per add at the board supply.
- Scaling: chains of L adds, closure `a + b + c`, crosstalk between channels.

## 2. Purchasable hardware

Toolchain notes (Grok's claims, **not independently checked**): AMD Vivado/Vitis hosts are x86-64 only, so the ARM64 Spark cannot build bitstreams for AMD/Xilinx parts; yosys, nextpnr and openFPGALoader can target Lattice ECP5. libiio is LGPL-2.1, UHD is GPL-3.0, ECP5 open tools are ISC/MIT. **verify** before relying on them.

| Product | What you get | Rate, bits, bandwidth | Host, toolchain | Cost, availability | Check status |
|---|---|---|---|---|---|
| RFSoC 4x2 (ZU48DR) | 4 ADC + 2 DAC, direct RF | ADC 5 GSPS 14-bit, 6 GHz input BW; DAC 9.85 GSPS 14-bit | Ethernet, USB3, JTAG. PYNQ (Python) is the shipped path; Vivado for fabric | Academic $2,499 (Real Digital). Commercial: quote. End Use Form required; academic buyers need AMD University Program approval. Older announcements said $2,149 | **VERIFIED** |
| ZCU111 (ZU28DR) | 8 ADC + 8 DAC | ADC 4.096 GSPS 12-bit; DAC 6.554 GSPS 14-bit | Vivado | $14,995 list, export form | **verify** (not checked) |
| ZCU216 (ZU49DR) | 16 ADC + 16 DAC | ADC 2.5 GSPS 14-bit; DAC up to 10 GSPS 14-bit | Vivado | $16,995 list | **verify** (not checked) |
| STEMlab 125-14 | 2 in + 2 out, baseband loopback | 125 MS/s, 14-bit both ways. Gen 2 BW DC-60 MHz (**verify**) | Ethernet + USB. Stock SCPI / C API; Vivado only to rebuild fabric. Board runs Linux | **[fixed]** Base starter kit $490 (redpitaya.com listing via search; product page blocked the fetch, **verify**). UK reseller: Gen 1 starter kit GBP 375, in stock. PRO Gen 2 starter kit $766; PRO Z7020 Gen 2 $1,061. Grok's "$720" is near the PRO tier, not the base kit | **WRONG DETAILS, fixed** |
| ADALM-PLUTO | 1 TX + 1 RX, AD9363, Zynq Z-7010 | 61.44 MS/s, 12-bit; RF 325 MHz to 3.8 GHz; 20 MHz instantaneous BW | USB 2.0, libiio (C). Linux on device | **[fixed]** About $215 to $280: ADI direct $233.25, Mouser $229.85, DigiKey $253.32, Newark $278.28, Arrow $215.63. Grok's "$399.99" is wrong | **WRONG DETAILS, fixed** |
| USRP B210 | 2x2 coherent, AD9361, 70 MHz to 6 GHz | 61.44 MS/s, 12-bit; 56 MHz BW (1x1) | USB 3.0, UHD (C++, GPL-3). No Linux on device | Ettus board-only $2,387. DigiKey $2,501.90; with enclosure about $2,578 to $2,729 | **VERIFIED** (price); BW figures not rechecked |
| ADALM2000 | 2-ch AWG + 2-ch scope | ADC 100 MS/s 12-bit; DAC 150 MS/s 12-bit | USB 2.0, libm2k (C++). Linux firmware on device | About $262 to $303: Richardson $262.47, DigiKey $274.94, Newark $302.69 | **VERIFIED** (price and converter rates) |
| ULX3S ECP5 | Open-source ECP5 board with onboard ADC | Onboard MAX11125: 8 channels, 12-bit, 1 MS/s (shared by multiplexer, so per-channel rate is lower, **verify**) | USB-JTAG + UART. yosys + nextpnr-ecp5, no vendor seat. aarch64 build of the tools: **verify** | 85F: $275, in stock (Crowd Supply, 2026-09-29), shipping $8 US. 12F: $155, pre-order, ships Dec 15 2026 | **VERIFIED** |
| Pmod DA4 | SPI DAC module, AD5628 | **[fixed]** 8 channels, 12-bit (Grok said 2 channels). Internal 1.25 V reference, gain 2 | SPI from the FPGA | $24.99 (TestEquity) to $27.00 (Digilent) | **WRONG DETAILS, fixed** (channel count only; price verified) |
| Mythic M1076 | Analog matrix-vector engine for NN weights. No phase adder | Not a sampled phase path | Closed SDK | No public price. Not a cart item | **verify** (not checked) |

## 3. What to buy (Grok's recommendation, prices corrected)

First step costs nothing: run the 32-bit phase-word twin in C on the Spark. It is the reference decoder every rig must match. (The group-law part of it already passes in the verification program above.)

Hold any purchase while:
- the C twin has not passed 9 x 1000;
- the existing bench has not been checked (any 2-channel generator plus 2-channel capture runs the same loopback at `f_c = f_s / 64`);
- the claim under test is still just the group law. A 5 GSPS converter does not change `(1+2) mod 3`.

When the twin is green, the bench is empty, and the claim is "real converters preserve the sum", Grok recommends:

- ULX3S ECP5-85F: $275 (+ $8 US shipping). The 12F ($155) has enough logic but is pre-order until December 2026.
- Pmod DA4: about $25 to $27.
- Bias divider, wire: about $15.

**Total about $320 to $325** with shipping. Open toolchain (yosys, nextpnr), host program in C, no Linux on the board. Same 9 x 1000 gate at `f_c = f_s / 64`, N = 1024. At 12-bit and -6 dBFS, `SNR_1` is about 68 dB, so `rho = 1024 x SNR_1 / 2` is about 3.2e9 (95 dB), still about 80 dB beyond the 1e-12 contour (about 77 dB for the two-phasor add). **VERIFIED** arithmetic.

Alternatives:
- ADALM2000 (about $262 to $303) if you want plus/minus 5 V and 100 MS/s without writing FPGA code, accepting Linux firmware on the device and no open FPGA flow.
- STEMlab 125-14 (base starter kit about $490, **verify**; PRO about $766) as the step up to the 1.95 MHz, 125 MS/s reference design, driven over SCPI from C.
- RFSoC 4x2, ZCU111, ZCU216, B210, Pluto and Mythic are later machines. Each adds an x86 toolchain, an RF carrier, or a closed SDK, and none changes `(1+2) mod 3`.
