import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly


async def send_sample(dut, value):
    dut.ui_in.value = value & 0xFF
    dut.uio_in.value = 0x01
    await RisingEdge(dut.clk)


async def wait_for_state(dut, state):
    while dut.user_project.state.value.to_unsigned() != state:
        await RisingEdge(dut.clk)

    await ReadOnly()


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
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0

    samples = [0, 1, 2, 3, 4, 5, 6, 7]

    for value in samples:
        dut._log.info(f"Sending sample: {value}")
        await send_sample(dut, value)

    dut.uio_in.value = 0

    await wait_for_state(dut, 2)

    mean = dut.user_project.mean.value.to_signed()

    dut._log.info(f"Mean = {mean}")

    assert mean == 3, f"Expected mean = 3, got {mean}"

    dut._log.info("Mean PASSED")

    await wait_for_state(dut, 5)

    variance = dut.user_project.variance.value.to_signed()

    dut._log.info(f"Variance = {variance}")

    assert variance == 5, f"Expected variance = 5, got {variance}"

    dut._log.info("Variance PASSED")

    inv_sqrt = dut.user_project.inv_sqrt.value.to_unsigned()

    dut._log.info(f"Inv sqrt = {inv_sqrt}")

    assert inv_sqrt == 1832, (
        f"Expected inv_sqrt = 1832, got {inv_sqrt}"
    )

    dut._log.info("Inv sqrt PASSED")
    dut._log.info("ALL TESTS PASSED")