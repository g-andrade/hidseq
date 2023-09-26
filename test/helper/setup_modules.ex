# credo:disable-for-this-file Credo.Check.Readability.ModuleNames
defmodule HidSeq_Test.Helper.SetupModules do
  @moduledoc false
  defmodule Base10 do
    @moduledoc false
    use HidSeq.Setup,
      key: :crypto.strong_rand_bytes(32),
      radix: 10
  end

  defmodule Base16 do
    @moduledoc false
    use HidSeq.Setup,
      key: :crypto.strong_rand_bytes(32),
      radix: 16,
      carefree_threshold: 0x100000
  end

  defmodule WrongKeySize do
    @moduledoc false
    use HidSeq.Setup,
      key: :crypto.strong_rand_bytes(31),
      radix: 10
  end

  defmodule InvalidRadix do
    @moduledoc false
    use HidSeq.Setup,
      key: :crypto.strong_rand_bytes(32),
      radix: 1
  end
end
