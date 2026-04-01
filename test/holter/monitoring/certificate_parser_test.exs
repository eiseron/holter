defmodule Holter.Monitoring.CertificateParserTest do
  use ExUnit.Case, async: true
  alias Holter.Monitoring.CertificateParser

  describe "decode_asn1_time/1" do
    test "correctly parses utcTime (short year >= 50)" do
      input = {:utcTime, ~c"991231235959Z"}
      assert CertificateParser.decode_asn1_time(input) == ~U[1999-12-31 23:59:59Z]
    end

    test "correctly parses utcTime (short year < 50)" do
      input = {:utcTime, ~c"250101000000Z"}
      assert CertificateParser.decode_asn1_time(input) == ~U[2025-01-01 00:00:00Z]
    end

    test "correctly parses generalTime (long year)" do
      input = {:generalTime, ~c"20400615120000Z"}
      assert CertificateParser.decode_asn1_time(input) == ~U[2040-06-15 12:00:00Z]
    end
  end

  describe "extract_expiration_from_otp/1" do
    test "extracts time from a mock OTP structure" do
      validity = {:Validity, nil, {:utcTime, ~c"491231235959Z"}}

      tbs = {
        :OTPTBSCertificate,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        validity,
        nil,
        nil,
        nil
      }

      otp_cert = {:OTPCertificate, tbs, nil, nil}

      result = CertificateParser.extract_expiration_from_otp(otp_cert)
      assert result == ~U[2049-12-31 23:59:59Z]
    end
  end
end
