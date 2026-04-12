#!/usr/bin/env ruby
# frozen_string_literal: true

require "objspace"
require "optparse"
require "securerandom"

require "bundler/setup"
require "active_support"
require "active_support/cache"
require "polyid"

options = {
  entries: 50_000,
  read_batch_sizes: [1, 10, 1_000],
  read_passes: 5,
  model_name: "BenchmarkModel",
}

OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby script/benchmark_cache_binary_uuids.rb [options]"

  parser.on("--entries COUNT", Integer, "Number of id/uuid pairs to cache (default: #{options[:entries]})") do |count|
    options[:entries] = count
  end

  parser.on("--read-batch-size COUNT", Integer, "Append a read_multi batch size (can be passed multiple times)") do |count|
    options[:read_batch_sizes] << count
  end

  parser.on("--read-passes COUNT", Integer, "Number of full read passes per mode (default: #{options[:read_passes]})") do |count|
    options[:read_passes] = count
  end

  parser.on("--model-name NAME", String, "Model name namespace used for cache keys (default: #{options[:model_name]})") do |name|
    options[:model_name] = name
  end
end.parse!

options[:read_batch_sizes] = options[:read_batch_sizes].uniq.sort

ids = (1..options[:entries]).to_a.freeze
uuids = Array.new(options[:entries]) { SecureRandom.uuid }.freeze

def measure(label)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  [label, elapsed]
end

def cache_data(store)
  store.instance_variable_get(:@data)
end

def cache_metrics(store)
  data = cache_data(store)
  entry_values = data.values.map { |entry| entry.instance_variable_get(:@value) }

  {
    entry_count: data.size,
    key_bytes: data.keys.sum(&:bytesize),
    string_value_bytes: entry_values.grep(String).sum(&:bytesize),
    binary_string_value_count: entry_values.count { |value| value.is_a?(String) && value.bytesize == 16 },
    approx_object_bytes: data.sum do |key, entry|
      value = entry.instance_variable_get(:@value)
      ObjectSpace.memsize_of(key) +
        ObjectSpace.memsize_of(entry) +
        ObjectSpace.memsize_of(value)
    end,
  }
end

def encode_uuid_binary(uuid)
  [uuid.delete("-")].pack("H*")
end

def decode_uuid_binary(uuid)
  return uuid unless uuid.is_a?(String) && uuid.bytesize == 16

  uuid.unpack("H8H4H4H4H12").join("-")
end

def id_key_current(model_name, id)
  "polyid/#{model_name}/id:#{id}"
end

def uuid_key_current(model_name, encoded_uuid)
  "polyid/#{model_name}/uuid:#{encoded_uuid}"
end

def id_key_compact(model_name, id)
  "polyid/#{model_name}/#{id}"
end

def uuid_key_binary_tag(model_name, encoded_uuid)
  "polyid/#{model_name}/b#{encoded_uuid}"
end

def uuid_key_hex(model_name, uuid)
  "polyid/#{model_name}/#{uuid.delete('-')}"
end

STRATEGIES = {
  current_binary: {
    label: "current_binary",
    id_key: method(:id_key_current),
    uuid_key: lambda { |model_name, uuid, encoded_uuid|
      uuid_key_current(model_name, encoded_uuid)
    },
    stored_uuid: lambda { |_uuid, encoded_uuid|
      encoded_uuid
    },
    decode_uuid: method(:decode_uuid_binary),
  },
  b_prefixed_binary: {
    label: "b_prefixed_binary",
    id_key: method(:id_key_compact),
    uuid_key: lambda { |model_name, uuid, encoded_uuid|
      uuid_key_binary_tag(model_name, encoded_uuid)
    },
    stored_uuid: lambda { |_uuid, encoded_uuid|
      encoded_uuid
    },
    decode_uuid: method(:decode_uuid_binary),
  },
  hex32_key_binary_value: {
    label: "hex32_key_binary_value",
    id_key: method(:id_key_compact),
    uuid_key: lambda { |model_name, uuid, _encoded_uuid|
      uuid_key_hex(model_name, uuid)
    },
    stored_uuid: lambda { |_uuid, encoded_uuid|
      encoded_uuid
    },
    decode_uuid: method(:decode_uuid_binary),
  },
}.freeze

def run_case(strategy_name:, ids:, uuids:, options:)
  strategy = STRATEGIES.fetch(strategy_name)
  store = ActiveSupport::Cache::MemoryStore.new

  timings = {}
  timings[:write] = measure(:write) do
    ids.zip(uuids) do |id, uuid|
      encoded_uuid = encode_uuid_binary(uuid)

      store.write_multi(
        strategy[:id_key].call(options[:model_name], id) => strategy[:stored_uuid].call(uuid, encoded_uuid),
        strategy[:uuid_key].call(options[:model_name], uuid, encoded_uuid) => id,
      )
    end
  end.last

  timings[:read_ids] = {}
  options[:read_batch_sizes].each do |batch_size|
    timings[:read_ids][batch_size] = measure(:"read_ids_#{batch_size}") do
      options[:read_passes].times do
        uuids.each_slice(batch_size) do |slice|
          uuid_key_map = slice.to_h do |uuid|
            encoded_uuid = encode_uuid_binary(uuid)
            [uuid, strategy[:uuid_key].call(options[:model_name], uuid, encoded_uuid)]
          end

          cached = store.read_multi(*uuid_key_map.values)
          uuid_key_map.each_value { |cache_key| cached[cache_key] }
        end
      end
    end.last
  end

  timings[:read_uuids] = {}
  options[:read_batch_sizes].each do |batch_size|
    timings[:read_uuids][batch_size] = measure(:"read_uuids_#{batch_size}") do
      options[:read_passes].times do
        ids.each_slice(batch_size) do |slice|
          id_key_map = slice.to_h { |id| [id, strategy[:id_key].call(options[:model_name], id)] }
          cached = store.read_multi(*id_key_map.values)
          id_key_map.each_value { |cache_key| strategy[:decode_uuid].call(cached[cache_key]) if cached.key?(cache_key) }
        end
      end
    end.last
  end

  metrics = cache_metrics(store)

  {
    mode: strategy[:label],
    timings: timings,
    metrics: metrics,
  }
end

def format_seconds(value)
  format("%.4fs", value)
end

def format_percent_delta(base, value)
  return "n/a" if base.zero?

  delta = ((value - base) / base.to_f) * 100
  format("%+.1f%%", delta)
end

results = STRATEGIES.keys.map do |strategy_name|
  run_case(strategy_name: strategy_name, ids: ids, uuids: uuids, options: options)
end

baseline = results.first

puts "PolyId cache benchmark"
puts "entries=#{options[:entries]} read_batch_sizes=#{options[:read_batch_sizes].join(',')} read_passes=#{options[:read_passes]}"
puts

results.each do |result|
  puts "#{result[:mode]} mode"
  puts "  write time:        #{format_seconds(result[:timings][:write])} (#{format_percent_delta(baseline[:timings][:write], result[:timings][:write])})"
  options[:read_batch_sizes].each do |batch_size|
    puts "  read ids x#{batch_size}:   #{format_seconds(result[:timings][:read_ids][batch_size])} (#{format_percent_delta(baseline[:timings][:read_ids][batch_size], result[:timings][:read_ids][batch_size])})"
  end
  options[:read_batch_sizes].each do |batch_size|
    puts "  read uuids x#{batch_size}: #{format_seconds(result[:timings][:read_uuids][batch_size])} (#{format_percent_delta(baseline[:timings][:read_uuids][batch_size], result[:timings][:read_uuids][batch_size])})"
  end
  puts "  cache entries:     #{result[:metrics][:entry_count]}"
  puts "  key bytes:         #{result[:metrics][:key_bytes]} (#{format_percent_delta(baseline[:metrics][:key_bytes], result[:metrics][:key_bytes])})"
  puts "  string value bytes #{result[:metrics][:string_value_bytes]} (#{format_percent_delta(baseline[:metrics][:string_value_bytes], result[:metrics][:string_value_bytes])})"
  puts "  binary values:     #{result[:metrics][:binary_string_value_count]}"
  puts "  approx object mem: #{result[:metrics][:approx_object_bytes]} (#{format_percent_delta(baseline[:metrics][:approx_object_bytes], result[:metrics][:approx_object_bytes])})"
  puts
end
