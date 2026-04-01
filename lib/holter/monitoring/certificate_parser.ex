defmodule Holter.Monitoring.CertificateParser do
  @moduledoc """
  Decodes Erlang/OTP certificate binaries and parses expiration dates.
  """

  def parse_expiry(cert_binary) do
    cert_binary
    |> decode_otp_cert()
    |> extract_expiration_from_otp()
  end

  def extract_expiration_from_otp(otp_cert) do
    otp_cert
    |> extract_validity()
    |> extract_not_after()
    |> decode_asn1_time()
  end

  defp decode_otp_cert(cert), do: :public_key.pkix_decode_cert(cert, :otp)

  defp extract_validity(otp_cert) do
    tbs_cert = elem(otp_cert, 1)
    elem(tbs_cert, 7)
  end

  defp extract_not_after({:Validity, _not_before, not_after}), do: not_after

  def decode_asn1_time({:utcTime, time}), do: parse_time(:short, List.to_string(time))
  def decode_asn1_time({:generalTime, time}), do: parse_time(:long, List.to_string(time))

  defp parse_time(:short, <<y::binary-2, rest::binary>>) do
    prefix = if String.to_integer(y) >= 50, do: "19", else: "20"
    to_datetime("#{prefix}#{y}", rest)
  end

  defp parse_time(:long, <<y::binary-4, rest::binary>>) do
    to_datetime(y, rest)
  end

  defp to_datetime(
         year,
         <<m::binary-2, d::binary-2, h::binary-2, min::binary-2, s::binary-2, "Z">>
       ) do
    {:ok, dt, _} = DateTime.from_iso8601("#{year}-#{m}-#{d}T#{h}:#{min}:#{s}Z")
    dt
  end
end
