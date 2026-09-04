import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly


STATE_NORM_LOAD = 6
STATE_OUT = 9


def signed8(value):
    value = int(value) & 0xff
    return value - 256 if value & 0x80 else value


async def wait_for_state(dut, state):
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()

        if int(dut.user_project.state.value) == state:
            return


@cocotb.test()
async def test_layernorm(dut):
    dut._log.info("Start LayerNorm test")

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    dut.uio_in.value = 0b10
    await RisingEdge(dut.clk)

    dut.uio_in.value = 0b11

    samples = [0, 1, 2, 3, 4, 5, 6, 7]

    for sample in samples:
        dut.ui_in.value = sample
        await RisingEdge(dut.clk)

    dut.uio_in.value = 0

    await wait_for_state(dut, STATE_NORM_LOAD)

    mean = dut.user_project.mean.value.to_signed()
    variance_sum = dut.user_project.variance_sum.value.to_signed()
    variance = dut.user_project.variance.value.to_signed()
    inv_sqrt = dut.user_project.inv_sqrt.value.to_unsigned()

    assert mean == 3
    assert variance_sum == 44
    assert variance == 5
    assert inv_sqrt == 229

    expected = [-1, 0, 0, 0, 0, 0, 1, 1]

    for expected_value in expected:
        await wait_for_state(dut, STATE_OUT)

        output = signed8(dut.uo_out.value)

        assert output == expected_value

        if expected_value != expected[-1]:
            await RisingEdge(dut.clk)

    dut._log.info("LayerNorm test PASSED")