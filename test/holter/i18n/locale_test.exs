defmodule Eiseron.I18n.LocaleTest do
  use ExUnit.Case, async: true

  alias Eiseron.I18n.Locale

  describe "supported/0" do
    test "returns the canonical Gettext-formatted locale strings" do
      assert Locale.supported() == ~w(en pt_BR)
    end
  end

  describe "default/0" do
    test "returns the configured application default locale" do
      configured =
        Application.get_env(:eiseron_core, Locale, [])
        |> Keyword.fetch!(:default_locale)

      assert Locale.default() == configured
    end
  end

  describe "valid?/1" do
    test "accepts every supported locale" do
      for locale <- Locale.supported() do
        assert Locale.valid?(locale), "expected #{inspect(locale)} to be valid"
      end
    end

    test "rejects locales outside supported/0" do
      refute Locale.valid?("de")
      refute Locale.valid?("pt")
      refute Locale.valid?("PT_BR")
      refute Locale.valid?("en-GB")
    end

    test "rejects non-binary input" do
      refute Locale.valid?(nil)
      refute Locale.valid?(:pt_BR)
      refute Locale.valid?(123)
      refute Locale.valid?(%{})
    end
  end

  describe "parse_accept_language/1" do
    test "returns en for the literal en tag" do
      assert Locale.parse_accept_language("en") == "en"
    end

    test "returns pt_BR for the literal pt_BR tag" do
      assert Locale.parse_accept_language("pt_BR") == "pt_BR"
    end

    test "normalizes hyphenated BCP-47 form to Gettext underscore form" do
      assert Locale.parse_accept_language("pt-BR") == "pt_BR"
    end

    test "case-folds a lowercase region so pt-br resolves to pt_BR" do
      assert Locale.parse_accept_language("pt-br") == "pt_BR"
    end

    test "case-folds a mixed-case language and region" do
      assert Locale.parse_accept_language("PT-br") == "pt_BR"
    end

    test "returns nil for bare language without a region" do
      assert Locale.parse_accept_language("pt") == nil
    end

    test "returns nil for an unsupported language code" do
      assert Locale.parse_accept_language("de") == nil
    end

    test "returns nil for an unsupported language-region pair" do
      assert Locale.parse_accept_language("fr-FR") == nil
    end

    test "selects the highest-quality supported tag from a weighted list" do
      header = "de;q=0.9, pt-BR;q=0.8, en;q=0.5"
      assert Locale.parse_accept_language(header) == "pt_BR"
    end

    test "treats missing q= as 1.0 and prefers the implicit-1.0 entry" do
      header = "en, pt-BR;q=0.8"
      assert Locale.parse_accept_language(header) == "en"
    end

    test "returns nil for an empty header" do
      assert Locale.parse_accept_language("") == nil
    end

    test "returns nil for a header full of separators only" do
      assert Locale.parse_accept_language(";;,;") == nil
    end

    test "returns nil when the input is nil" do
      assert Locale.parse_accept_language(nil) == nil
    end

    test "returns nil when the input is an atom" do
      assert Locale.parse_accept_language(:pt_BR) == nil
    end

    test "returns nil when the input is an integer" do
      assert Locale.parse_accept_language(123) == nil
    end

    test "ignores extraneous whitespace around tags and parameters" do
      assert Locale.parse_accept_language("  pt-BR ; q=0.9 , en ; q=0.5  ") == "pt_BR"
    end

    test "treats malformed q values as the default 1.0 weight" do
      assert Locale.parse_accept_language("pt-BR;q=abc") == "pt_BR"
    end

    test "is the first q= parameter wins when duplicated" do
      assert Locale.parse_accept_language("pt-BR;q=0.1;q=0.9, en;q=0.5") == "en"
    end

    test "still picks the supported tag from a 5000-entry adversarial header" do
      header = String.duplicate("xx-YY;q=0.5,", 5_000) <> "pt-BR;q=0.9"

      assert Locale.parse_accept_language(header) == "pt_BR"
    end

    test "completes parsing of a 5000-entry adversarial header in under 1s" do
      header = String.duplicate("xx-YY;q=0.5,", 5_000) <> "pt-BR;q=0.9"

      {micros, _result} = :timer.tc(fn -> Locale.parse_accept_language(header) end)

      assert micros < 1_000_000
    end
  end
end
