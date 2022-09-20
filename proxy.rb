require 'sinatra'
require 'sorbet-runtime'
require 'ipaddr'
require 'time'
require 'json'
require 'excon'

class Node < T::Struct
  const :ID, Integer
  const :StableID, String
  const :Name, String
  const :Key, String
  const :KeyExpiry, DateTime
  const :Machine, String
  const :DiscoKey, String
  const :Addresses, T::Array[IPAddr]
  const :AllowedIPs, T::Array[IPAddr]
  const :Endpoints, T::Array[IPAddr]
  const :DERP, IPAddr
  const :Hostinfo, T::Hash[String, String]
  const :Created, DateTime
  const :Online, T::Boolean
  const :ComputedName, String
  const :ComputedNameWithHost, String
end

class UserProfile < T::Struct
  const :ID, Integer
  const :LoginName, String
  const :DisplayName, String
  const :ProfilePicURL, String
  const :Roles, T::Array[String]
end

class WhoisResponse < T::Struct
  const :Node, Node
  const :UserProfile, UserProfile
end

class TailscaleOPProxy < Sinatra::Application
  def tailscale_whois(request)
    conn = Excon.new('unix:/local-tailscaled.sock', socket: '/var/run/tailscale/tailscaled.sock')
    response = conn.request(method: :get, path: "/localapi/v0/whois?addr=#{request.ip}")
    WhoisResponse.from_hash(JSON.parse(response.body))
  end

  get '/secrets' do
    whois = tailscale_whois(request)
    whois.serialize.to_json
  end
end
