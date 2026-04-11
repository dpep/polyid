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
  read_batch_size: 1_000,
  read_passes: 5,
  model_name: "BenchmarkModel",
}

OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby script/benchmark_cache_binary_uuids.rb [options]"

  parser.on("--entries COUNT", Integer, "Number of id/uuid pairs to cache (default: #{options[:entries]})") do |count|
    options[:entries] = count
  end

  parser.on("--read-batch-size COUNT", Integer, "read_multi batch size (default: #{options[:read_batch_size]})") do |count|
    options[:read_batch_size] = count
  end

  parser.on("--read-passes COUNT", Integer, "Number of full read passes per mode (default: #{options[:read_passes]})") do |count|
    options[:read_passes] = count
  end

  parser.on("--model-name NAME", String, "Model name namespace used for cache keys (default: #{options[:model_name]})") do |name|
    options[:model_name] = name
  end
end.parse!

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

def run_case(binary:, ids:, uuids:, options:)
  PolyId.reset
  PolyId.cache = ActiveSupport::Cache::MemoryStore.new
  PolyId.cache_binary_uuids = binary

  timings = {}
  timings[:write] = measure(:write) do
    ids.zip(uuids) do |id, uuid|
      PolyId::Cache.write(options[:model_name], id: id, uuid: uuid)
    end
  end.last

  timings[:read_ids] = measure(:read_ids) do
    options[:read_passes].times do
      uuids.each_slice(options[:read_batch_size]) do |slice|
        PolyId::Cache.read_multi(options[:model_name], uuids: slice)
      end
    end
  end.last

  timings[:read_uuids] = measure(:read_uuids) do
    options[:read_passes].times do
      ids.each_slice(options[:read_batch_size]) do |slice|
        PolyId::Cache.read_multi(options[:model_name], ids: slice)
      end
    end
  end.last

  metrics = cache_metrics(PolyId.cache)

  {
    mode: binary ? "binary" : "string",
    timings: timings,
    metrics: metrics,
  }
ensure
  PolyId.reset
end

def format_seconds(value)
  format("%.4fs", value)
end

def format_percent_delta(base, value)
  return "n/a" if base.zero?

  delta = ((value - base) / base.to_f) * 100
  format("%+.1f%%", delta)
end

results = [
  run_case(binary: false, ids: ids, uuids: uuids, options: options),
  run_case(binary: true, ids: ids, uuids: uuids, options: options),
]

baseline = results.first

puts "PolyId cache benchmark"
puts "entries=#{options[:entries]} read_batch_size=#{options[:read_batch_size]} read_passes=#{options[:read_passes]}"
puts

results.each do |result|
  puts "#{result[:mode]} mode"
  puts "  write time:        #{format_seconds(result[:timings][:write])} (#{format_percent_delta(baseline[:timings][:write], result[:timings][:write])})"
  puts "  read ids time:     #{format_seconds(result[:timings][:read_ids])} (#{format_percent_delta(baseline[:timings][:read_ids], result[:timings][:read_ids])})"
  puts "  read uuids time:   #{format_seconds(result[:timings][:read_uuids])} (#{format_percent_delta(baseline[:timings][:read_uuids], result[:timings][:read_uuids])})"
  puts "  cache entries:     #{result[:metrics][:entry_count]}"
  puts "  key bytes:         #{result[:metrics][:key_bytes]} (#{format_percent_delta(baseline[:metrics][:key_bytes], result[:metrics][:key_bytes])})"
  puts "  string value bytes #{result[:metrics][:string_value_bytes]} (#{format_percent_delta(baseline[:metrics][:string_value_bytes], result[:metrics][:string_value_bytes])})"
  puts "  binary values:     #{result[:metrics][:binary_string_value_count]}"
  puts "  approx object mem: #{result[:metrics][:approx_object_bytes]} (#{format_percent_delta(baseline[:metrics][:approx_object_bytes], result[:metrics][:approx_object_bytes])})"
  puts
end
