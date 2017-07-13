# vim: set expandtab ts=2 sw=2:
require_relative 'lib/simp/metadata'
require 'yaml'
require 'pry'
require 'pry-byebug'
$UPSTREAMREPO="https://github.com/simp/simp-core.git"
begin
  Dir.mkdir("scratch")
  Dir.mkdir("data")
  Dir.mkdir("data/releases")
rescue
end
Dir.chdir("scratch") do
  unless Dir.exists?("upstream")
    `git clone #{$UPSTREAMREPO} upstream`
  else
    Dir.chdir("upstream") do
      `git fetch origin`
    end
  end
end
data = {}
data['components'] = {}
data['releases'] = {}
components = data['components']
component_by_url = {}

class Puppetfile
  def initialize()
    @repos = {}
    @moduledir = "/"
  end
  def repos()
    @repos
  end
  def mod(name, params = {})
    @repos[name] = params.merge({"destination" => @moduledir})
  end
  def forge(url)
    puts url
  end
  def moduledir(name)
    @moduledir = "/#{name}"
  end
end

def parse_git(url)
  case url
  when /^https:/
    https_url = url.split("/")
    host = https_url[2]
    path = https_url.drop(3).join("/")
    type = "https"
  when /^git@/
    git_url = url.split(":")
    host = git_url[0].gsub("git@","")
    path = git_url[1]
    type = "ssh"
  when /^git:/
    git_url = url.split("/")
    host = git_url[2]
    path = git_url.drop(3).join("/")
    type = "ssh"
  end
  return { "host" => host, "path" => path, "type" => type }
end

repo_url = {}
Dir.chdir("scratch/upstream") do
  branches = "master\n6.0.0-Alpha-Release\n" + `git tag -l`
  branches.split("\n").each do |branch|
    begin
      pfile = Puppetfile.new
      `git checkout #{branch}`
      if File.exists?("Puppetfile.stable")
        release = {}
        pfile.instance_eval(File.read("Puppetfile.stable").gsub("}",""))
        pfile.repos.each do |key, value|
          ret = {}
          ret["type"] = "git"
          ret["authoritative"] = true
          gitinfo = parse_git(value[:git])
          ret["primary_source"] = gitinfo.dup.delete_if { |key, value| key == "type" }
          object = {
            "ref" => value[:ref],
            "type" => gitinfo["type"],
            "path" => value["destination"]
          }
          if (component_by_url.key?(ret["primary_source"]))
            release[component_by_url[ret["primary_source"]]] = object
          else
            [ "", "-1", "-2", "-3", "-4", "-5", "-6" ].each do |opt|
              nkey = key + opt
              ret["mirrors"] = { "gitlab" => { "host" => "gitlab.com", "path" => "simp/" + nkey}}
              if (components.key?(nkey))
                if components[nkey]["type"] != ret["type"] && components[nkey]["primary_source"] != ret["primary_source"]
                  next
                else
                  release[nkey] = object
                  break
                end
              else
                components[nkey] = ret
                component_by_url[ret["primary_source"]] = nkey
                release[nkey] = object
                break
              end
            end
          end
        end
      end
      data['releases'][branch] = release
      #    rescue
    end
  end
end
comp = { "components" => components }
File.open("data/components.yaml", 'w') {|f| f.write comp.to_yaml }

data['releases'].each do |key, value|
  release = { "releases" => { key => value } }
  File.open("data/releases/#{key}.yaml", 'w') {|f| f.write release.to_yaml }
end
