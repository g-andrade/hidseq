defmodule HidSeq.SensibleFormatter do
  alias HidSeq.Formatter
  alias HidSeq.Utils

  @default_radix_or_alphabet 10

  @enforce_keys [:codec]
  defstruct [:codec]

  @opaque t :: %__MODULE__{codec: FF3_1.FFX.Codec.t()}

  ## API

  def new!(radix_or_alphabet \\ @default_radix_or_alphabet) do
    {:ok, formatter} = new(radix_or_alphabet)
    formatter
  end

  def new(radix_or_alphabet \\ @default_radix_or_alphabet) do
    case Utils.new_codec(radix_or_alphabet) do
      {:ok, codec} ->
        {:ok, %__MODULE__{codec: codec}}

      {:error, _} = error ->
        error
    end
  end

  ## Formatter

  defimpl Formatter, for: __MODULE__ do
    alias HidSeq.SensibleFormatter

    ## API

    def encode!(%SensibleFormatter{codec: codec}, integer) do
      alias FF3_1.FFX.Codec

      numerical_string = Codec.int_to_padded_numerical_string(codec, integer, _pad_count = 0)
      format_recur(numerical_string, _first_split = true)
    end

    def decode(_formatter, not_a_string) when not is_binary(not_a_string) do
      {:error, {:not_a_string, not_a_string}}
    end

    def decode(%SensibleFormatter{codec: codec}, string) do
      alias FF3_1.FFX.Codec

      numerical_string = String.split(string, "-", trim: true) |> Enum.join()
      Codec.numerical_string_to_int(codec, numerical_string)
    end

    ## Internal

    defp format_recur(string, first_split \\ false) do
      len = String.length(string)

      if len >= 5 do
        half_len = div(len, 2)

        min_tail_chunk_len =
          if first_split do
            4
          else
            3
          end

        n = max(half_len, len - min_tail_chunk_len)

        {left, right} = String.split_at(string, n)
        "#{format_recur(left)}-#{format_recur(right)}"
      else
        string
      end
    end
  end
end
