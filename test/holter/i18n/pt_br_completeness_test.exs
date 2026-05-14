defmodule Holter.I18n.PtBrCompletenessTest do
  use ExUnit.Case, async: true

  for po_file <- Path.wildcard("priv/gettext/pt_BR/LC_MESSAGES/*.po") do
    domain = po_file |> Path.basename() |> Path.rootname()

    describe "pt_BR/#{domain}.po" do
      @po_path po_file

      test "has no untranslated singular entries (empty msgstr)" do
        content = File.read!(@po_path)
        entries = parse_singular_entries(content)

        untranslated =
          Enum.filter(entries, fn {msgid, msgstr} ->
            msgid != "" and msgstr == ""
          end)

        assert untranslated == [],
               "pt_BR/#{Path.basename(@po_path)} has #{length(untranslated)} untranslated " <>
                 "entries. Every user-facing string must have a pt_BR translation.\n" <>
                 Enum.map_join(untranslated, "\n", fn {id, _} ->
                   ~s(  msgid "#{id}")
                 end)
      end

      test "has no untranslated plural entries (empty msgstr[0] or msgstr[1])" do
        content = File.read!(@po_path)
        entries = parse_plural_entries(content)

        untranslated =
          Enum.filter(entries, fn {msgid, msgstr0, msgstr1} ->
            msgid != "" and (msgstr0 == "" or msgstr1 == "")
          end)

        assert untranslated == [],
               "pt_BR/#{Path.basename(@po_path)} has #{length(untranslated)} untranslated " <>
                 "plural entries.\n" <>
                 Enum.map_join(untranslated, "\n", fn {id, _, _} ->
                   ~s(  msgid "#{id}")
                 end)
      end

      test "has no fuzzy entries" do
        content = File.read!(@po_path)
        fuzzy_lines = Regex.scan(~r/^#,.*\bfuzzy\b/m, content)

        assert fuzzy_lines == [],
               "pt_BR/#{Path.basename(@po_path)} has #{length(fuzzy_lines)} fuzzy entries — " <>
                 "fuzzy translations are placeholders that need manual review. Resolve them " <>
                 "and remove the fuzzy flag."
      end
    end
  end

  defp parse_singular_entries(content) do
    Regex.scan(~r/^msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"/m, content,
      capture: :all_but_first
    )
    |> Enum.map(fn [msgid, msgstr] -> {msgid, msgstr} end)
  end

  defp parse_plural_entries(content) do
    Regex.scan(
      ~r/^msgid "((?:[^"\\]|\\.)*)"\nmsgid_plural "[^"]*"\nmsgstr\[0\] "((?:[^"\\]|\\.)*)"\nmsgstr\[1\] "((?:[^"\\]|\\.)*)"/m,
      content,
      capture: :all_but_first
    )
    |> Enum.map(fn [msgid, msgstr0, msgstr1] -> {msgid, msgstr0, msgstr1} end)
  end
end
