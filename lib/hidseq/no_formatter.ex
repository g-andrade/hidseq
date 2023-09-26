defmodule HidSeq.NoFormatter do
  @moduledoc false
  alias HidSeq.Formatter

  @enforce_keys []
  defstruct []

  @opaque t :: %__MODULE__{}

  ## API

  def new! do
    %__MODULE__{}
  end

  ## Formatter

  defimpl Formatter, for: __MODULE__ do
    alias HidSeq.NoFormatter

    ## API

    def encode!(%NoFormatter{}, integer) do
      integer
    end

    def decode(%NoFormatter{}, value) do
      if is_integer(value) and value >= 0 do
        {:ok, value}
      else
        {:error, {:not_a_non_negative_integer, value}}
      end
    end
  end
end
