module Simp
  module Metadata
    class Engine
      def initialize(path = nil)
        if (path == nil)
          @path = Dir.mktmpdir("simp-metadata")
        else
          @path = File.absolute_path(path);
        end
        @data = {}
        Dir.chdir(@path) do
          unless (Dir.exists?(@path + "/data"))
          	`git clone https://github.com/simp/simp-metadata data`	
          end
          Dir.chdir("data") do
            Dir.glob("**/*.yaml") do |filename|
              begin
                hash = YAML.load_file("/" + filename)
                @data = self.deep_merge(@data, hash)
              end
            end
          end
        end
      end
      def deep_merge(target_hash, source_hash)
        source_hash.each do |key, value|
          if (target_hash.key?(key))
            if (value.class == Hash)
              self.deep_merge(target_hash[key], value)
            else
              target_hash[key] = value
            end
          else
            target_hash[key] = value
          end
        end
        target_hash
      end
      def url(component)
          record = @data['components'][component]
          primary = record["primary_source"]
          url = "https://#{primary["host"]}/#{primary["path"]}"
      end
      def component_list(version = nil)
        list = []
        @data['components'].each do |key, value|
          list << key
        end
        list
      end
      def list_components_with_data(version = nil)
        if (version == nil)
          raise "Must specify version"
        end
        list = self.component_list(version)
        retval = {}
        list.each do |component|
          info = self.component_info(component, version)
          if (info != nil)
            unless (retval.key?(info["path"]))
              retval[info["path"]] = {}
            end
            retval[info["path"]][component] = info
          end
        end
        return retval
      end
      def component_info(component, version = nil)
        retval = nil
        if @data["releases"].key?(version)
          if @data["releases"][version].key?(component)
            retval = @data["releases"][version][component].merge({ "source" => @data["components"][component]})
          end
        end
        return retval
      end
    end
  end
end

