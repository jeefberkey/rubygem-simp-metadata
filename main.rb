# vim: set expandtab ts=2 sw=2:
require_relative 'lib/simp/metadata'
require 'optparse'
require 'ostruct'
require 'pp'
require 'pry'
require 'json'
require 'yaml'

command, *args = ARGV;
metadata = Simp::Metadata::Engine.new("data")
def rest_request(request, method = "GET", body = nil)
  require 'net/http'
  require 'uri'

  uri = URI.parse(request)
  case method
  when "POST"
    request = Net::HTTP::Post.new(uri)
  when "GET"
    request = Net::HTTP::Get.new(uri)
  when "PUT"
    request = Net::HTTP::Put.new(uri)
  when "DELETE"
    request = Net::HTTP::Delete.new(uri)
  end
  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  # response.code
  JSON.parse(response.body)
end

# config = YAML.load_file("config.yaml")
# gitlabtoken = config["gitlab"]["token"]
# result = rest_request("https://gitlab.com/api/v3/runners?private_token=#{gitlabtoken}")

case command
when "generate"
  options = OpenStruct.new
  options.puppetfile = false
  options.release = nil
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: main.rb generate [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on("-p", "--puppetfile", "Generate puppetfile") do |p|
      options.puppetfile = p
    end
    opts.on("-r", "--release=MANDATORY", "Release to generate") do |r|
      options.release = r
    end
  end
  opt_parser.parse!(args)
  if options.release == nil
    puts "must specify -r or --release"
    exit 1
  end
  if options.puppetfile == true
    paths = metadata.list_components_with_data(options.release)
    file = []
    paths.each do | key, value|
      path = key.slice(1, key.length)
      file << "moduledir #{path}"
      file << ""
      value.each do |modulename, modinfo|
         file << "mod '#{modulename}',"
         url = metadata.url(modulename)
         file << "    :git => '#{url}'"
         file << "    :ref => '#{modinfo["ref"]}'"
         file << ""
      end
    end
    puts file.join("\n")
  end
when "mirror"
  options = OpenStruct.new
  options.puppetfile = false
  options.destination = "scratch/mirror"
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: main.rb mirror [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on("-d", "--destination", "Specify destination") do |p|
      options.destination = p
    end
    opts.on("-u", "--url", "Specify destination url") do |p|
      options.destination = p
    end
  end
  opt_parser.parse!(args)
  begin
    Dir.mkdir(options.destination)
  rescue
  end
  Dir.chdir(options.destination) do
    components = metadata.component_list()
    components.each do |component|
      url = metadata.url(component)
      `git clone #{url} #{component}`
    end
  end
when "fixtures"
  options = OpenStruct.new
  options.release = "master"
  options.module = "simp"
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: main.rb fixtures [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on("-r", "--release", "Specify release (6.0.0-0, master, upstream-master)") do |p|
      options.release = p
    end
    opts.on("-m", "--module", "Specify module name") do |p|
      options.module = p
    end
  end
  opt_parser.parse!(args)

  fixture_repos = {}
  metadata.list_components_with_data(options.release)["/src/puppet/modules"].each do |mod, data|
    source = data["source"]["primary_source"]
    fixture_repos[mod.split('-')[1]] = {
      "repo" => "#{data['type']}://#{source['host']}/#{source['path']}",
      "branch" => "master"
    }

    # binding.pry.byebug
  end

  fixtures_yml = {
    "fixtures" => {
      "repositories" => fixture_repos,
      "symlinks" => {
        options.module => '#{source_dir}'
      }
    }
  }
  File.write('scratch/.fixtures.yml', fixtures_yml.to_yaml)

  # pry
end
