defmodule HidseqTest do
  use ExUnit.Case

  test "setup modules working fine" do
    alias HidSeq_Test.Helper.SetupModules

    id = 423_423_409_017
    test_setup_module(SetupModules.Base10, id)

    id = 0x423423017AFDE
    test_setup_module(SetupModules.Base16, id)
  end

  test "setup modules with wrong opts" do
    alias HidSeq_Test.Helper.SetupModules

    _ = Process.flag(:trap_exit, true)

    assert match?(
             {:error, {:key_has_invalid_size, _}},
             SetupModules.WrongKeySize.start_link()
           )

    assert match?(
             {:error, {:invalid_radix, _}},
             SetupModules.InvalidRadix.start_link()
           )
  end

  test "setup module server alternative termination flows" do
    alias HidSeq_Test.Helper.SetupModules

    _ = Process.flag(:trap_exit, true)

    {:ok, pid} = SetupModules.Base10.start_link()
    assert match?({:ok, _ctx}, HidSeq.Setup.Server.get_ctx(SetupModules.Base10))
    HidSeq.Setup.Server.stop(pid, :"everything's crashing")
    assert match?({:ok, _ctx}, HidSeq.Setup.Server.get_ctx(SetupModules.Base10))

    {:ok, pid} = SetupModules.Base10.start_link()
    HidSeq.Setup.Server.stop(pid, :shutdown)

    assert HidSeq.Setup.Server.get_ctx(SetupModules.Base10) ===
             {:error, {:ctx_not_found_for_module, SetupModules.Base10}}

    {:ok, pid} = SetupModules.Base10.start_link()
    HidSeq.Setup.Server.stop(pid, {:shutdown, :detailed_reason})

    assert HidSeq.Setup.Server.get_ctx(SetupModules.Base10) ===
             {:error, {:ctx_not_found_for_module, SetupModules.Base10}}
  end

  ## Helpers

  defp test_setup_module(module, id) do
    assert HidSeq.Setup.Server.get_ctx(module) === {:error, {:ctx_not_found_for_module, module}}

    {:ok, pid} = module.start_link()
    {:ok, ctx} = HidSeq.Setup.Server.get_ctx(module)

    encrypted_and_formatted_id = module.encrypt_and_format!(id)
    assert module.decrypt(encrypted_and_formatted_id) === {:ok, id}

    assert encrypted_and_formatted_id === HidSeq.encrypt_and_format!(ctx, id)

    :ok = HidSeq.Setup.Server.stop(pid)
    assert HidSeq.Setup.Server.get_ctx(module) === {:error, {:ctx_not_found_for_module, module}}
  end
end
