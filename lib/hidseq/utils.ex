defmodule HidSeq.Utils do
  @moduledoc false

  @doc false
  def new_codec(radix_or_alphabet) do
    alias FF3_1.FFX.Codec

    case Codec.Builtin.maybe_new(radix_or_alphabet) do
      {:ok, _codec} = success ->
        success

      nil ->
        new_custom_codec(radix_or_alphabet)
    end
  end

  ## Internal

  defp new_custom_codec(radix) when is_integer(radix) do
    {:error, :you_need_to_specify_an_alphabet}
  end

  defp new_custom_codec(alphabet) when is_binary(alphabet) do
    alias FF3_1.FFX.Codec

    case Codec.Custom.new(alphabet) do
      {:ok, _codec} = success ->
        success

      {:error, _} = error ->
        error
    end
  end

  defp new_custom_codec(invalid) do
    {:error, {:neither_a_radix_nor_an_alphabet, invalid}}
  end
end
