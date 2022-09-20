require 'sinatra'
require 'sorbet-runtime'
require 'ipaddr'
require 'time'
require 'json'
require 'excon'
require 'pp'

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
  const :User, Integer
  const :Tags, T::Array[String], default: []
end

class UserProfile < T::Struct
  const :ID, Integer
  const :LoginName, String
  const :DisplayName, String
  const :ProfilePicURL, String
  const :Roles, T::Array[String], default: []
end

class WhoisResponse < T::Struct
  const :Node, Node
  const :UserProfile, UserProfile
end

class OPSection < T::Struct
  const :id, String
  const :label, T.nilable(String)
end

class OPField < T::Struct
  const :id, String
  const :type, String
  const :purpose, T.nilable(String)
  const :label, String
  const :value, T.nilable(String)
  const :section, T.nilable(OPSection)
end

class OPFile < T::Struct
  const :id, String
  const :name, String
  const :size, Integer
  const :content_path, String
end

class OPItem < T::Struct
  const :id, String
  const :title, String
  const :tags, T::Array[String], default: []
  const :vault, T::Hash[String, String]
  const :category, String
  const :sections, T::Array[OPSection], default: []
  const :fields, T::Array[OPField], default: []
  const :files, T::Array[OPFile], default: []
  const :createdAt, DateTime
  const :updatedAt, DateTime
end

class TailscaleOPProxy < Sinatra::Application
  def tailscale_whois(request)
    conn = Excon.new('unix:/local-tailscaled.sock', socket: '/var/run/tailscale/tailscaled.sock')
    response = conn.request(method: :get, path: "/localapi/v0/whois?addr=#{request.ip}:1")
    WhoisResponse.from_hash(JSON.parse(response.body))
  end

  def all_secrets
    conn = Excon.new('http://op-connect-api:8080', headers: {"Authorization" => "Bearer #{ENV['OP_CONNECT_API_TOKEN']}"})
    response = conn.request(method: :get, path: "/v1/vaults/#{ENV['OP_CONNECT_VAULT_ID']}/items")

    JSON.parse(response.body).map do |item|
      item_resp = conn.request(method: :get, path: "/v1/vaults/#{ENV['OP_CONNECT_VAULT_ID']}/items/#{item['id']}")
      OPItem.from_hash(JSON.parse(item_resp.body))
    end
  end

  def secrets_for_tags(tags)
    tags = tags.dup.map { |t| t.gsub(/tag:/, '') }
    secrets = all_secrets.select { |s| (s.tags & tags).length > 0 }

    secrets.flat_map do |item|
      item.fields.map do |field|
        next unless field.type == 'STRING'
        next if field.label =~ /notesPlain/
        [field.label, field.value]
      end
    end.compact
  end

  get '/secrets' do
    whois = tailscale_whois(request)
    secrets_for_tags(whois.Node.Tags).to_json
  end
end
