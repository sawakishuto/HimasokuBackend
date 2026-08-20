# frozen_string_literal: true

# apnotic 1.7.2 の Apnotic::ProviderToken#signature は、ES256 署名を
# OpenSSL の ASN.1(DER) 形式（先頭 0x30 の SEQUENCE / 可変長 70〜72 バイト）で
# 出力する。しかし JWT(JOSE, RFC 7518) の ES256 は「生の r||s 連結（各 32 バイト
# 固定 = 計 64 バイト）」を要求するため、DER のままだと Apple APNS に
# InvalidProviderToken で拒否される。
#
# ここでは署名生成のみを差し替え、DER → 生 r||s へ変換して仕様準拠の JWT を作る。
# gem 本体の header / payload / encode はそのまま利用する。
require 'apnotic'
require 'openssl'

module Apnotic
  class ProviderToken
    private

    def signature
      asn1  = @key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
      r, s  = OpenSSL::ASN1.decode(asn1).value.map(&:value)
      [r, s].map { |bn| bn.to_s(2).rjust(32, "\x00".b) }.join
    end

    def signing_input
      [encode(header), encode(payload)].join('.')
    end
  end
end
