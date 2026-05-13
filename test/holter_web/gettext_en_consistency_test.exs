defmodule HolterWeb.GettextEnConsistencyTest do
  use ExUnit.Case, async: true

  @en_default_po "priv/gettext/en/LC_MESSAGES/default.po"

  describe "en/default.po" do
    test "has no fuzzy entries" do
      content = File.read!(@en_default_po)
      fuzzy_lines = Regex.scan(~r/^#,.*\bfuzzy\b/m, content)

      assert fuzzy_lines == [],
             "en/default.po has #{length(fuzzy_lines)} fuzzy entries — fuzzy en translations" <>
               " desyncronize the UI from the source strings. Resolve them manually by setting" <>
               " msgstr to match msgid (or to a clean human translation) and remove the fuzzy flag."
    end

    test "every msgstr matches its msgid (or is empty)" do
      content = File.read!(@en_default_po)
      entries = parse_entries(content)

      mismatches =
        Enum.filter(entries, fn {msgid, msgstr} ->
          msgid != "" and msgstr != "" and msgid != msgstr
        end)

      assert mismatches == [],
             "en/default.po has msgstr values that don't match msgid. The English locale is the" <>
               " source — `mix gettext.extract --merge` produces these as fuzzy candidates that" <>
               " must be resolved. Mismatched entries:\n" <>
               Enum.map_join(mismatches, "\n", fn {id, str} ->
                 ~s(  msgid "#{id}" -> msgstr "#{str}")
               end)
    end
  end

  defp parse_entries(content) do
    Regex.scan(~r/^msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"/m, content,
      capture: :all_but_first
    )
    |> Enum.map(fn [msgid, msgstr] -> {msgid, msgstr} end)
  end
end
