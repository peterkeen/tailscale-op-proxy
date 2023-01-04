require 'sinatra'
require 'sorbet-runtime'
require 'ipaddr'
require 'time'
require 'json'
require 'excon'
require 'pp'

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
  def all_secrets
    conn = Excon.new('http://op-connect-api:8080', headers: {"Authorization" => "Bearer #{ENV['OP_CONNECT_API_TOKEN']}"})
    response = conn.request(method: :get, path: "/v1/vaults/#{ENV['OP_CONNECT_VAULT_ID']}/items")

    JSON.parse(response.body).map do |item|
      item_resp = conn.request(method: :get, path: "/v1/vaults/#{ENV['OP_CONNECT_VAULT_ID']}/items/#{item['id']}")
      OPItem.from_hash(JSON.parse(item_resp.body))
    end
  end

  def tags_for_server_token(token)
    all_secrets.flat_map do |item|
      next unless item.category == "SERVER"
      item_token = item.fields.detect { |f| f.label == "token" }&.value
      next unless Rack::Utils.secure_compare(token, item_token)

      return item.tags
    end

    nil
  end

  def secrets_for_tags(tags)
    tags ||= ["tag:server"]
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
    sigil, token = env['HTTP_AUTHORIZATION']&.split(/\s+/, 2)

    if sigil.nil?
      return secrets_for_tags(nil).to_json
    end

    tags = tags_for_server_token(token)
    if tags.nil?
      halt 401, {'Content-Type' => 'application/json'}, {error: "unauthorized"}.to_json
    else
      secrets_for_tags(tags).to_json
    end
  end
end
