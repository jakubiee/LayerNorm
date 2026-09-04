import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


def signed8(value):
    value = int(value) & 0xff
    return value - 256 if value & 0x80 else value


async def wait_cycles(dut, cycles):
    for _ in range(cycles):
        await RisingEdge(dut.clk)


async def run_layernorm(dut, samples):
    dut.uio_in.value = 0b10
    await RisingEdge(dut.clk)

    dut.uio_in.value = 0b11

    for sample in samples:
        dut.ui_in.value = sample & 0xff
        await RisingEdge(dut.clk)

    dut.uio_in.value = 0

    for _ in range(100):
        await RisingEdge(dut.clk)
        value = signed8(dut.uo_out.value)
        if value != 0:
            outputs = [value]

            for _ in range(7):
                await wait_cycles(dut, 4)
                outputs.append(signed8(dut.uo_out.value))

            return outputs

    raise AssertionError("No output received")


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

    await wait_cycles(dut, 3)

    dut.rst_n.value = 1

    samples = [0, 1, 2, 3, 4, 5, 6, 7]
    expected = [-1, 0, 0, 0, 0, 0, 1, 1]

    outputs = await run_layernorm(dut, samples)

    assert outputs == expected, (
        f"Expected {expected}, got {outputs}"
    )

    dut._log.info("LayerNorm test PASSED")