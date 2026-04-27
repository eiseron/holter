defmodule Holter.Delivery.WebhookSignature do
  @moduledoc """
  Builds the `X-Holter-Signature` header for outbound webhook deliveries.

  Format: `t=<unix>,v1=<hex>` where `<hex>` is the lowercase hex encoding
  of HMAC-SHA256 over the string `"<unix>.<body>"` keyed by the channel's
  signing token. The leading timestamp lets receivers reject stale
  deliveries, and the HMAC means the secret never travels the wire.
  """

  @header_name "x-holter-signature"

  def header_name, do: @header_name

  @doc """
  Builds the `{header_name, header_value}` tuple for the given body, token
  and timestamp. Pure transformer.
  """
  def build_signature_header(body, token, %DateTime{} = now)
      when is_binary(body) and is_binary(token) do
    unix = DateTime.to_unix(now)
    hmac = compute_hmac(token, "#{unix}.#{body}")
    {@header_name, "t=#{unix},v1=#{hmac}"}
  end

  @doc """
  HMAC-SHA256 of `signed_payload` keyed by `token`, lowercase hex encoded.
  Pure transformer.
  """
  def compute_hmac(token, signed_payload) when is_binary(token) and is_binary(signed_payload) do
    :crypto.mac(:hmac, :sha256, token, signed_payload) |> Base.encode16(case: :lower)
  end
end
