defmodule Barbecue.IO.MAX31856 do
  @moduledoc """
  Implements the MAX31856 thermocouple.

  Datasheet:
  https://www.analog.com/media/en/technical-documentation/data-sheets/max31856.pdf

  To figure out if the sensor is wired correctly, a few sanity checks can be
  done by reading out the default values of the registers.

  ```elixir
  {:ok, buffer} = read_register(ref, @cr0)
  <<0, 0>> = buffer

  {:ok, buffer} = read_register(ref, @cr1)
  <<0, 0x03>> = buffer

  {:ok, buffer} = read_register(ref, @mask)
  <<0, 0xFF>> = buffer

  {:ok, buffer} = read_register(ref, @cjhf)
  <<0, 0x7F>> = buffer

  # set the mask value to 0x00 and verify
  {:ok, _buffer} = write_register(ref, @mask, 0x00)
  {:ok, buffer} = read_register(ref, @mask)
  <<0, 0x00>> = buffer

  # set the value back to the default
  {:ok, _buffer} = write_register(ref, @mask, 0xFF)
  {:ok, buffer} = read_register(ref, @mask)
  <<0, 0xFF>> = buffer
  ```
  """
  import Bitwise

  alias Circuits.SPI

  require Logger

  # registers read
  @cr0 0x00
  @cr1 0x01
  @mask 0x02
  @ltcbh 0x0C

  # bitmasks to configure the sensor
  @cr0_autoconvert 0x80
  @cr0_oneshot 0x40

  # @thermocouple_b 0x00
  # @thermocouple_e 0x01
  # @thermocouple_j 0x02
  @thermocouple_k 0x03
  # @thermocouple_n 0x04
  # @thermocouple_r 0x05
  # @thermocouple_s 0x06
  # @thermocouple_t 0x07

  @device "spidev0.1"

  @doc """
  Initialize the thermocouple.
  """
  @spec init() :: {:ok, term()}
  def init() do
    # open the spi port
    {:ok, ref} = SPI.open(@device, mode: 1, speed_hz: 500_000, lsb_first: false)

    # assert on any fault
    {:ok, _buffer} = write_register(ref, @mask, 0x00)

    # configure open circuit faults
    {:ok, _buffer} = write_register(ref, @cr0, 0x10)

    # set the thermocouple type
    set_thermocouple(ref)

    {:ok, ref}
  end

  defp set_thermocouple(ref, thermocouple \\ @thermocouple_k) do
    # set the thermocouple
    {:ok, <<_, cr1>>} = read_register(ref, @cr1)
    cr1 = (cr1 &&& 0xF0) ||| thermocouple
    {:ok, _buffer} = write_register(ref, @cr1, cr1)
  end

  @doc """
  Measure the temperature of the thermocouple.
  """
    @spec measure(reference()) :: {:error, :measure_failed} | {:ok, float()}
  def measure(ref) do
    prepare_one_shot(ref)
    do_measure(ref, 10)
  end

  @spec do_measure(reference(), non_neg_integer()) :: {:error, :measure_failed} | {:ok, float()}
  def do_measure(ref, tries) do
    case tries do
      0 ->
        {:error, :measure_failed}

      _n ->
        if one_shot_pending?(ref) do
          Process.sleep(100)
          do_measure(ref, tries - 1)
        else
          read_temperature(ref)
        end
    end
  end

  @spec one_shot_pending?(reference()) :: boolean()
  def one_shot_pending?(ref) do
    # one shot pending?
    {:ok, <<_, cr0>>} = read_register(ref, @cr0)

    not ((cr0 &&& @cr0_oneshot) == 0)
  end

  @spec read_temperature(reference()) :: {:ok, float()}
  def read_temperature(ref) do
    # unpack temperature
    {:ok, buffer} = read_register4(ref, @ltcbh)
    <<temp::32>> = buffer
    {:ok, temp / 4096.0}
  end

  @spec prepare_one_shot(reference()) :: :ok
  def prepare_one_shot(ref) do
    # initiate one-shot
    {:ok, <<_, cr0>>} = read_register(ref, @cr0)
    # unset the auto-convert bit
    cr0 = cr0 &&& ~~~@cr0_autoconvert
    # set the one-shot bit
    cr0 = cr0 ||| @cr0_oneshot

    # update the config register
    {:ok, _buffer} = write_register(ref, @cr0, cr0)

    :ok
  end

  @spec read_register(reference(), non_neg_integer()) :: {:ok, <<_::16, _::_*8>>}
  def read_register(reference, register) do
    register = register &&& 0x7F
    {:ok, _result} = write_bin(reference, <<register, 0x00>>)
  end

  @spec read_register4(reference(), non_neg_integer()) :: {:ok, <<_::32, _::_*8>>}
  def read_register4(reference, register) do
    register = register &&& 0x7F
    {:ok, _result} = write_bin(reference, <<register, 0x00, 0x00, 0x00>>)
  end

  @spec write_register(reference(), non_neg_integer(), non_neg_integer()) ::
          {:ok, <<_::16, _::_*8>>}
  def write_register(reference, register, value) do
    # writing address for a register is computed with &&& 0x80
    register = register ||| 0x80
    buffer = <<register, value>>
    write_bin(reference, buffer)
  end

  @spec write_bin(reference(), <<_::_*8>>) :: {:ok, <<_::_*8>>}
  def write_bin(reference, bin) do
    # IO.inspect(bin, label: ">>")
    {:ok, result} = SPI.transfer(reference, bin)
    # IO.inspect(result, label: "<<")
    {:ok, result}
  end
end
