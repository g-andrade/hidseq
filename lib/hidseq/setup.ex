# credo:disable-for-this-file Credo.Check.Design.AliasUsage
# credo:disable-for-this-file Credo.Check.Readability.ModuleNames
defmodule HidSeq.Setup do
  @moduledoc false
  @type opts :: [
          key: HidSeq.key(),
          carefree_threshold: pos_integer,
          radix: HidSeq.radix(),
          formatter: HidSeq.Formatter.t()
        ]

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      ## API

      def child_spec do
        HidSeq.Setup.Server.child_spec(server_args())
      end

      def start_link do
        HidSeq.Setup.Server.start_link(server_args())
      end

      def encrypt!(id) do
        HidSeq.encrypt!(ctx(), id)
      end

      def encrypt_and_format!(id) do
        HidSeq.encrypt_and_format!(ctx(), id)
      end

      def decrypt(encrypted_and_formatted_id) do
        HidSeq.decrypt(ctx(), encrypted_and_formatted_id)
      end

      def ctx do
        {:ok, ctx} = HidSeq.Setup.Server.get_ctx(__MODULE__)
        ctx
      end

      ## Internal Functions

      defp server_args do
        opts = unquote(opts)

        %HidSeq.Setup.Server.Args{
          module: __MODULE__,
          key: opts[:key],
          opts: opts
        }
      end
    end
  end
end
