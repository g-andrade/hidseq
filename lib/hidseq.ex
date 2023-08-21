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
    :algo
  ])

  @type ctx ::
          record(:hidseq_ctx,
            header_shift: pos_integer,
            body_mask: pos_integer,
            body_ffx_len: pos_integer,
            algo: algo
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

  def new_ff3_1(key, carefree_threshold \\ @default_carefree_threshold) do
    bits_per_symbol = calc_best_fitting_bits_per_symbol(carefree_threshold)
    radix = 1 <<< bits_per_symbol
    {:ok, codec} = FF3_1.FFX.Codec.NoSymbols.new(radix)

    case FF3_1.new_ctx(key, codec) do
      {:ok, algo_ctx} ->
        body_ffx_len = ceil(:math.log2(carefree_threshold) / bits_per_symbol)
        header_shift = bits_per_symbol * body_ffx_len
        body_mask = (1 <<< header_shift) - 1
        algo = hidseq_database_id_ff3_1(ctx: algo_ctx)

        {:ok,
         hidseq_ctx(
           header_shift: header_shift,
           body_mask: body_mask,
           body_ffx_len: body_ffx_len,
           algo: algo
         )}

      {:error, _} = error ->
        error
    end
  end

  def encrypt!(ctx, id) when id >= 0 do
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      header_shift: header_shift,
      body_mask: body_mask,
      body_ffx_len: body_ffx_len,
      algo: algo
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = id >>> header_shift
    tweak = <<header::56>>
    body = id &&& body_mask
    plaintext = %NumString{value: body, length: body_ffx_len}
    ciphertext = FF3_1.encrypt!(algo_ctx, tweak, plaintext)
    ciphertext_int = ciphertext.value

    bor(header <<< header_shift, ciphertext_int)
  end

  def decrypt!(ctx, encrypted_id) when encrypted_id >= 0 do
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_ctx(
      header_shift: header_shift,
      body_mask: body_mask,
      body_ffx_len: body_ffx_len,
      algo: algo
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = encrypted_id >>> header_shift
    Logger.debug("header is #{header}")
    tweak = <<header::56>>
    body = encrypted_id &&& body_mask
    ciphertext = %NumString{value: body, length: body_ffx_len}
    plaintext = FF3_1.decrypt!(algo_ctx, tweak, ciphertext)
    plaintext_int = plaintext.value

    bor(header <<< header_shift, plaintext_int)
  end

  ## Internal

  defp calc_best_fitting_bits_per_symbol(carefree_threshold) do
    # We go in descending order to prioritize the larger radix when there's a tie
    15..1
    |> Enum.min_by(&calc_min_bitsize(&1, carefree_threshold))
  end

  def calc_min_bitsize(bits_per_symbol, carefree_threshold) do
    exponent = ceil(:math.log2(carefree_threshold) / bits_per_symbol)
    bits_per_symbol * exponent
  end
end
