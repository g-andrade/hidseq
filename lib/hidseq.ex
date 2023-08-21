defmodule DatabaseId do
  require Logger
  require Record
  import Bitwise

  ## Constants

  @world_population_2023 8_000_000_000
  @default_carefree_threshold 5 * @world_population_2023

  ## Types

  Record.defrecordp(:hidseq_ctx, [
    :header_shift,
    :body_mask,
    :body_ffx_len,
    :algo,
    :formatter
  ])

  @type ctx ::
          record(:hidseq_ctx,
            header_shift: pos_integer,
            body_mask: pos_integer,
            body_ffx_len: pos_integer,
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
        formatter \\ HidSeq.SensibleFormatter.new!()
      ) do
    bits_per_symbol = calc_best_fitting_bits_per_symbol(carefree_threshold)
    radix = 1 <<< bits_per_symbol
    {:ok, codec} = FF3_1.FFX.Codec.NoSymbols.new(radix)

    case FF3_1.new_ctx(key, codec) do
      {:ok, algo_ctx} ->
        %{min_length: min_body_ffx_length} = FF3_1.constraints(algo_ctx)

        body_ffx_len =
          max(
            min_body_ffx_length,
            ceil(:math.log2(carefree_threshold) / bits_per_symbol)
          )

        header_shift = bits_per_symbol * body_ffx_len
        body_mask = (1 <<< header_shift) - 1
        algo = hidseq_database_id_ff3_1(ctx: algo_ctx)

        {:ok,
         hidseq_ctx(
           header_shift: header_shift,
           body_mask: body_mask,
           body_ffx_len: body_ffx_len,
           algo: algo,
           formatter: formatter
         )}

      {:error, _} = error ->
        error
    end
  end

  def encrypt!(ctx, id) when id >= 0 do
    alias HidSeq.Formatter
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      header_shift: header_shift,
      body_mask: body_mask,
      body_ffx_len: body_ffx_len,
      algo: algo,
      formatter: formatter
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = id >>> header_shift
    tweak = <<header::56>>
    body = id &&& body_mask
    plaintext = %NumString{value: body, length: body_ffx_len}
    ciphertext = FF3_1.encrypt!(algo_ctx, tweak, plaintext)
    ciphertext_int = ciphertext.value

    encrypted = bor(header <<< header_shift, ciphertext_int)
    Formatter.encode!(formatter, encrypted)
  end

  def decrypt(ctx, encrypted_and_formatted) do
    alias HidSeq.Formatter
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      header_shift: header_shift,
      body_mask: body_mask,
      body_ffx_len: body_ffx_len,
      algo: algo,
      formatter: formatter
    ) = ctx

    case Formatter.decode(formatter, encrypted_and_formatted) do
      {:ok, encrypted} ->
        hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

        header = encrypted >>> header_shift
        Logger.debug("header is #{header}")
        tweak = <<header::56>>
        body = encrypted &&& body_mask
        ciphertext = %NumString{value: body, length: body_ffx_len}
        plaintext = FF3_1.decrypt!(algo_ctx, tweak, ciphertext)
        plaintext_int = plaintext.value

        {:ok, bor(header <<< header_shift, plaintext_int)}

      {:error, _} = error ->
        error
    end
  end

  ## Internal

  defp calc_best_fitting_bits_per_symbol(carefree_threshold) do
    # We go in descending order to prioritize the larger radix when there's a tie
    15..1
    |> Enum.min_by(&calc_min_bitsize(&1, carefree_threshold))
  end

  defp calc_min_bitsize(bits_per_symbol, carefree_threshold) do
    exponent = ceil(:math.log2(carefree_threshold) / bits_per_symbol)
    bits_per_symbol * exponent
  end
end
