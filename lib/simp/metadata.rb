# vim: set expandtab ts=2 sw=2:
module Simp
  module Metadata
    class Engine
      def initialize(path)
        @path = File.absolute_path(path);
        @data = {}
        Dir.chdir(@path) do
          Dir.glob("**/*.yaml") do |filename|
            begin
              hash = YAML.load_file(@path + "/" + filename)
              @data = @data.merge(hash)
            end
          end
        end
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

