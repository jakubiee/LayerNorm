import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def send_sample(dut, value):
    dut.ui_in.value = value & 0xFF
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)


@cocotb.test()
async def test_layernorm(dut):
    dut._log.info("Start LayerNorm test")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    dut.uio_in.value = 0b10
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0

    samples = [0, 1, 2, 3, 4, 5, 6, 7]

    for value in samples:
        dut._log.info(f"Sending sample: {value}")
        await send_sample(dut, value)

    dut.uio_in.value = 0

    await ClockCycles(dut.clk, 1)

    mean = dut.user_project.mean.value.to_signed()

    dut._log.info(f"Mean = {mean}")

    assert mean == 3, f"Expected mean = 3, got {mean}"

    dut._log.info("Mean PASSED")

    await ClockCycles(dut.clk, 8)

    variance = dut.user_project.variance.value.to_signed()

    dut._log.info(f"Variance = {variance}")

    assert variance == 5, f"Expected variance = 5, got {variance}"

    dut._log.info("Variance PASSED")

    await ClockCycles(dut.clk, 1)

    inv_sqrt = dut.user_project.inv_sqrt.value.to_unsigned()

    dut._log.info(f"Inv sqrt = {inv_sqrt}")

    assert inv_sqrt == 1832, (
        f"Expected inv_sqrt = 1832, got {inv_sqrt}"
    )

    dut._log.info("Inv sqrt PASSED")

    expected = [-3, -2, -1, 0, 1, 2, 3, 4]
    outputs = []

    for expected_value in expected:
        value = dut.uo_out.value.to_signed()

        dut._log.info(
            f"Output = {value}, expected = {expected_value}"
        )

        outputs.append(value)

        assert value == expected_value, (
            f"Expected {expected_value}, got {value}"
        )

        await ClockCycles(dut.clk, 1)

    assert outputs == expected, (
        f"Expected {expected}, got {outputs}"
    )

    dut._log.info("Output vector PASSED")
    dut._log.info("ALL TESTS PASSED")