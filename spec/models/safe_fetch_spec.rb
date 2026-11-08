# frozen_string_literal: true

require "rails_helper"

RSpec.describe SafeFetch do
  describe ".parse" do
    it "accepts http and https URLs, also with umlauts" do
      expect(described_class.parse("https://www.auer-packaging.com/de/Eurobehälter/ED 43.html").path)
        .to eq "/de/Eurobeh%C3%A4lter/ED%2043.html"
    end

    it "rejects everything else" do
      [ "file:///etc/passwd", "ftp://example.com/", "javascript:alert(1)", "http://example.com:22/",
        "http://user:pass@example.com/", "not a url", "" ].each do |url|
        expect { described_class.parse(url) }.to raise_error(described_class::Error), url
      end
    end
  end

  describe ".resolve!" do
    it "blocks private, loopback, link-local and mapped addresses" do
      [ "http://127.0.0.1/", "http://localhost/", "http://[::1]/", "http://10.1.2.3/", "http://192.168.0.1/",
        "http://172.16.0.1/", "http://169.254.169.254/", "http://[::ffff:10.0.0.1]/", "http://0.0.0.0/",
        "http://2130706433/" ].each do |url|
        expect { described_class.resolve!(described_class.parse(url)) }
          .to raise_error(described_class::Error, /public address/), url
      end
    end

    it "blocks host names that resolve to a private address" do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([ Addrinfo.ip("10.0.0.7") ])

      expect { described_class.resolve!(described_class.parse("http://evil.example/")) }
        .to raise_error(described_class::Error, /public address/)
    end

    it "blocks a host name if only one of its addresses is private" do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([ Addrinfo.ip("93.184.216.34"), Addrinfo.ip("127.0.0.1") ])

      expect { described_class.resolve!(described_class.parse("http://rebind.example/")) }
        .to raise_error(described_class::Error)
    end

    it "returns the address of public hosts" do
      allow(Addrinfo).to receive(:getaddrinfo).and_return([ Addrinfo.ip("93.184.216.34") ])

      expect(described_class.resolve!(described_class.parse("https://example.org/")).to_s).to eq "93.184.216.34"
    end
  end
end
