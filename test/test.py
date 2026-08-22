# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def send_sample(dut, value):
    dut.ui_in.value = value & 0xFF
    dut.uio_in.value = 0x01

    await ClockCycles(dut.clk, 1)


@cocotb.test()
async def test_layernorm(dut):
    dut._log.info("Start")

    # Clock
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Initial value
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    dut._log.info("Reset")

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Start transaction
    dut.uio_in.value = 0b00000010
    await ClockCycles(dut.clk, 1)

    dut.uio_in.value = 0

    samples = [0, 1, 2, 3, 4, 5, 6, 7]

    for val in samples:
        dut._log.info(f"Sending sample: {val}")
        await send_sample(dut, val)

    await ClockCycles(dut.clk, 1)

    mean = dut.user_project.mean.value.signed_integer

    dut._log.info(f"Calculated mean = {mean}")

    assert mean == 3, (f"Expected mean = 3, got {mean}")

    dut._log.info("Mean calculation PASSED")