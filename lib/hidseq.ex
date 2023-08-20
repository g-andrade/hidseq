defmodule DatabaseId do
  require Record
  import Bitwise

  ## Constants

  # @world_population_2022 7_942_000_000
  @world_population 8_055_545_973
  @default_carefree_threshold 100 * @world_population

  ## Types

  Record.defrecordp(:hidseq_database_id_ctx, [
    :algo,
    :header_multiplier,
    :body_len
  ])

  @type ctx ::
          record(:hidseq_database_id_ctx,
            algo: algo,
            header_multiplier: non_neg_integer,
            body_len: non_neg_integer
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

  def new_ff3_1(key, carefree_threshold \\ @default_carefree_threshold)
      when is_integer(carefree_threshold) and carefree_threshold >= 0 do
    radix = best_radix(carefree_threshold)
    {:ok, codec} = FF3_1.FFX.Codec.NoSymbols.new(radix)

    case FF3_1.new_ctx(key, codec) do
      {:ok, algo_ctx} ->
        header_exp = ceil(:math.log(carefree_threshold) / :math.log(radix))
        header_multiplier = Integer.pow(radix, header_exp)
        body_len = header_exp
        algo = hidseq_database_id_ff3_1(ctx: algo_ctx)

        {:ok,
         hidseq_database_id_ctx(
           algo: algo,
           header_multiplier: header_multiplier,
           body_len: body_len
         )}

      {:error, _} = error ->
        error
    end
  end

  def encrypt!(ctx, id) when id >= 0 do
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_database_id_ctx(
      algo: algo,
      header_multiplier: header_multiplier,
      body_len: body_len
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = div(id, header_multiplier)
    tweak = <<header::56>>
    body = rem(id, header_multiplier)
    plaintext = %NumString{value: body, length: body_len}
    ciphertext = FF3_1.encrypt!(algo_ctx, tweak, plaintext)
    ciphertext_int = ciphertext.value

    bor(header <<< header_multiplier, ciphertext_int)
  end

  def decrypt!(ctx, encrypted_id) when encrypted_id >= 0 do
    alias FF3_1.FFX.Codec.NoSymbols.NumString

    hidseq_database_id_ctx(
      algo: algo,
      header_multiplier: header_multiplier,
      body_len: body_len
    ) = ctx

    hidseq_database_id_ff3_1(ctx: algo_ctx) = algo

    header = div(encrypted_id, header_multiplier)
    tweak = <<header::56>>
    body = rem(encrypted_id, header_multiplier)
    ciphertext = %NumString{value: body, length: body_len}
    plaintext = FF3_1.decrypt!(algo_ctx, tweak, ciphertext)
    plaintext_int = plaintext.value

    bor(header <<< header_multiplier, plaintext_int)
  end

  ## Internal

  defp best_radix(carefree_threshold) do
    best_radix_recur(_radix = 2, carefree_threshold, _best = nil, _best_imprecision = nil)
  end

  defp best_radix_recur(radix, carefree_threshold, best, best_imprecision) when radix <= 65535 do
    imprecision = :math.fmod(carefree_threshold, radix)

    if best_imprecision === nil or imprecision <= best_imprecision do
      if imprecision == 0 and radix >= 16 do
        radix
      else
        best_radix_recur(radix + 1, carefree_threshold, radix, imprecision)
      end
    else
      best_radix_recur(radix + 1, carefree_threshold, best, best_imprecision)
    end
  end

  defp best_radix_recur(_radix, _carefree_threshold, best, _best_imprecision) do
    best
  end
end
