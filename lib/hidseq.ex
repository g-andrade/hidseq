defmodule DatabaseId do
  require Logger
  require Record

  ## Constants

  @default_radix 10
  @default_carefree_threshold 1_000_000_000

  ## Types

  defmodule ParsedNewOpts do
    @moduledoc false
    @enforce_keys [:radix, :formatter]
    defstruct [:radix, :formatter]
  end

  Record.defrecordp(:hidseq_ctx, [
    :threshold,
    :encrypted_length,
    :algo,
    :formatter
  ])

  @type ctx ::
          record(:hidseq_ctx,
            threshold: pos_integer,
            encrypted_length: pos_integer,
            algo: algo,
            formatter: HidSeq.Formatter.t()
          )

  @typep algo :: ff3_1_algo

  # FF3-1 algo

  Record.defrecord(:hidseq_database_id_ff3_1, [
    :ctx
  ])

  @typep ff3_1_algo ::
           record(:hidseq_database_id_ff3_1,
             ctx: FF3_1.ctx()
           )

  ## API

  def new_ff3_1(
        key,
        carefree_threshold \\ @default_carefree_threshold,
        opts \\ []
      ) do
    with radix = opts[:radix] || @default_radix,
         {:ok, codec} <- FF3_1.FFX.Codec.NoSymbols.new(radix),
         {:ok, algo_ctx} <- FF3_1.new_ctx(key, codec),
         %{min_length: min_encrypted_length, max_length: max_encrypted_length} =
           FF3_1.constraints(algo_ctx),
         {:ok, encrypted_length} <- validate_threshold(carefree_threshold, radix),
         :ok <-
           validate_encrypted_length(
             carefree_threshold,
             encrypted_length,
             min_encrypted_length,
             max_encrypted_length
           ),
         {:ok, formatter} = validate_formatter(opts, radix) do
      algo = hidseq_database_id_ff3_1(ctx: algo_ctx)

      {:ok,
       hidseq_ctx(
         threshold: carefree_threshold,
         encrypted_length: encrypted_length,
         algo: algo,
         formatter: formatter
       )}
    else
      {:error, _} = error ->
        error
    end
  end

  def encrypt!(ctx, id) when is_integer(id) and id >= 0 do
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      threshold: threshold,
      encrypted_length: encrypted_length,
      algo: algo
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = div(id, threshold)
    tweak = <<header::56>>

    plaintext = %NumString{
      value: rem(id, threshold),
      length: encrypted_length
    }

    ciphertext = FF3_1.encrypt!(algo_ctx, tweak, plaintext)
    header * threshold + ciphertext.value
  end

  def encrypt_and_format!(ctx, id) do
    alias HidSeq.Formatter

    encrypted_id = encrypt!(ctx, id)
    formatter = hidseq_ctx(ctx, :formatter)
    Formatter.encode!(formatter, encrypted_id)
  end

  def decrypt(ctx, encrypted_and_formatted_id) do
    alias HidSeq.Formatter
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      threshold: threshold,
      encrypted_length: encrypted_length,
      algo: algo,
      formatter: formatter
    ) = ctx

    case Formatter.decode(formatter, encrypted_and_formatted_id) do
      {:ok, encrypted_id} ->
        hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

        header = div(encrypted_id, threshold)
        tweak = <<header::56>>

        ciphertext = %NumString{
          value: rem(encrypted_id, threshold),
          length: encrypted_length
        }

        plaintext = FF3_1.decrypt!(algo_ctx, tweak, ciphertext)

        id = header * threshold + plaintext.value
        {:ok, id}

      {:error, _} = error ->
        error
    end
  end

  ## Internal

  defp validate_threshold(value, radix) when is_integer(value) and value >= 2 do
    threshold_length = Integer.to_string(value, radix) |> String.length()
    encrypted_length = Integer.to_string(value - 1, radix) |> String.length()

    if encrypted_length + 1 == threshold_length do
      {:ok, encrypted_length}
    else
      {:error, {:invalid_threshold, {:not_lowest_value_of_its_length, value}}}
    end
  end

  defp validate_threshold(value, _radix) do
    {:error, {:invalid_threshold, {:not_a_integer_greater_than_or_equal_to_2, value}}}
  end

  defp validate_encrypted_length(threshold, value, min, max) do
    cond do
      value in min..max ->
        :ok

      value < min ->
        # threshold has one more digit than value
        threshold_min = min + 1
        {:error, {:invalid_threshold, {:length_too_short, threshold, min: threshold_min}}}

      value > max ->
        # threshold has one more digit than value
        threshold_max = max + 1
        {:error, {:invalid_threshold, {:length_too_long, threshold, max: threshold_max}}}
    end
  end

  defp validate_formatter(opts, radix) do
    case opts[:formatter] do
      %{__struct__: _} = formatter ->
        {:ok, formatter}

      nil ->
        HidSeq.SensibleFormatter.new(radix)
    end
  end
end
