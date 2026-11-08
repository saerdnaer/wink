# frozen_string_literal: true

require "net/http"
require "ipaddr"
require "socket"

# Fetches a URL given by a user without letting the server be used to reach
# internal systems (SSRF): only http(s) on the standard ports, every address the
# host name resolves to must be public, the connection goes to the checked
# address (no second DNS lookup), redirects are checked again, and time and size
# are limited.
class SafeFetch
  class Error < StandardError; end

  Response = Struct.new(:body, :content_type, :url)

  MAX_REDIRECTS = 3
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  PORTS = [ 80, 443 ].freeze

  BLOCKED_NETWORKS = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24
    203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 64:ff9b::/96 100::/64 2001:db8::/32 fc00::/7 fe80::/10 ff00::/8
  ].map { |network| IPAddr.new(network) }.freeze

  def self.get(url, max_bytes:, accept: "*/*")
    uri = parse(url)

    (MAX_REDIRECTS + 1).times do
      ip = resolve!(uri)
      response = request(uri, ip, max_bytes, accept)

      case response
      when Response then return response
      else uri = parse(URI.join(uri.to_s, response).to_s) # a redirect target
      end
    end

    raise Error, "too many redirects"
  end

  # Returns the URI for a user supplied string or raises Error.
  def self.parse(url)
    # URLs copied from a browser may contain umlauts and spaces
    escaped = url.to_s.strip.gsub(/[^\x21-\x7E]/) { |char| char.bytes.map { |byte| format("%%%02X", byte) }.join }
    uri = URI.parse(escaped)

    raise Error, "only http and https URLs are allowed" unless uri.is_a?(URI::HTTP) && uri.host.present?
    raise Error, "URLs with a user name or password are not allowed" if uri.userinfo
    raise Error, "port #{uri.port} is not allowed" unless PORTS.include?(uri.port)

    uri
  rescue URI::InvalidURIError
    raise Error, "this is not a valid URL"
  end

  # Resolves the host and returns the address to connect to. Raises Error if any
  # address is not public.
  def self.resolve!(uri)
    addresses = addresses_for(uri.host.delete_prefix("[").delete_suffix("]"))
    raise Error, "could not resolve #{uri.host}" if addresses.empty?
    raise Error, "#{uri.host} is not a public address" if addresses.any? { |ip| blocked?(ip) }

    addresses.first
  end

  def self.addresses_for(host)
    [ IPAddr.new(host) ]
  rescue IPAddr::InvalidAddressError
    Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map { |info| IPAddr.new(info.ip_address) }.uniq
  rescue SocketError
    []
  end

  def self.blocked?(ip)
    ip = ip.native if ip.ipv6? # ::ffff:10.0.0.1 is 10.0.0.1
    BLOCKED_NETWORKS.any? { |network| network.family == ip.family && network.include?(ip) }
  end

  # Returns a Response, or the Location of a redirect (String).
  def self.request(uri, ip, max_bytes, accept)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = ip.to_s # connect to the address we checked
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "Mozilla/5.0 (compatible; WINK inventory import)"
    request["Accept"] = accept

    http.start do
      http.request(request) do |response|
        case response
        when Net::HTTPSuccess
          return Response.new(read_limited(response, max_bytes), response["Content-Type"].to_s, uri.to_s)
        when Net::HTTPRedirection
          raise Error, "redirect without location" if response["Location"].blank?

          return response["Location"]
        else
          raise Error, "the server answered with HTTP #{response.code}"
        end
      end
    end
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "the server did not answer in time"
  rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "could not connect (#{e.class.name.demodulize.underscore.tr('_', ' ')})"
  end

  def self.read_limited(response, max_bytes)
    body = +"".b
    response.read_body do |chunk|
      body << chunk
      raise Error, "the response is larger than #{max_bytes / 1.megabyte} MB" if body.bytesize > max_bytes
    end
    body
  end

  private_class_method :request, :read_limited, :addresses_for
end
