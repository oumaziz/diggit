require 'fileutils'
require 'json'
require 'pp'
require 'set'

class Dockerfileduplicates < Diggit::Analysis
	require_addons 'out'

	INSTRUCTIONS = %w[
		ADD ARG CMD COPY ENTRYPOINT ENV EXPOSE FROM HEALTHCHECK LABEL
	  MAINTAINER ONBUILD RUN SHELL STOPSIGNAL USER VOLUME WORKDIR
	].freeze

	def initialize(options)
		super(options)
	end

	def run
		path = out.out_path_for_analysis(self)
		internals, externals = find_duplicates()
		
		create_analysis_dir(path)
		save_to_file("#{path}/internal_duplications.json", JSON.pretty_generate(internals))
		save_to_file("#{path}/external_duplications.json", JSON.pretty_generate(externals))
	end

	def save_to_file(filename, data)
		File.open(filename,"w") do |f|
      f.puts(data)
    end
	end

	def split_run(arguments)
	  tmp = arguments.scan(/([^\"\&;]+)|(\"[^\"]*\")|([\&;]*)/)
	  args = []
	  append = false

	  tmp.each { |arg|
	    if !arg[1].nil?
	      args[args.size - 1] = args[args.size - 1] + arg[1].strip.downcase
	    elsif !arg[2].nil?
	      append = false
	      args[args.size - 1] = args[args.size - 1].strip.downcase
	    else
	      if append
	        args[args.size - 1] = args[args.size - 1] + arg[0].strip.downcase
	      else
	        args.push("run " + arg[0].lstrip.downcase)
	        append = true
	      end
	    end
	  }

	  return args
	end

	def parse_dockerfile(path)
	  dockerfile_commands = []
	  extended_dockerfile = []

	  File.read(path).each_line do |line|
	    line = line.strip
	    if !line.start_with?("#") && !line.empty?
	      if INSTRUCTIONS.include? line.split(" ")[0].upcase
	        dockerfile_commands.push({"instruction" => line.split(" ")[0].upcase,
	                                  "arguments" => line.split(" ")[1..-1].join(" ").gsub('\\', '')})
	      else
	        dockerfile_commands[dockerfile_commands.size - 1]["arguments"].concat(line.strip.gsub('\\', ''))
	      end
	    end
	  end

	  dockerfile_commands.each { |command|
	    if command["instruction"] == INSTRUCTIONS[12]
	      if command["arguments"].strip.start_with? "["
	        extended_dockerfile.push(command["instruction"].strip.downcase + " " + command["arguments"].strip.downcase)
	      else
	          if command["arguments"].scan(/&&/).length > 0 || command["arguments"].count(";") > 0
	            extended_dockerfile.concat split_run(command["arguments"])
	          else
	            extended_dockerfile.push(command["instruction"].strip.downcase + " " + command["arguments"].strip.downcase)
	          end
	      end
	    else
	      extended_dockerfile.push(command["instruction"].strip.downcase + " " + command["arguments"].strip.downcase)
	    end
	  }

	  return extended_dockerfile
	end

	def find_duplicates()
		internals = {}
		externals = {}

		Dir.chdir("#{@source.folder}") do
			Dir["**/Dockerfile"].each do |f|
				begin
					tmp = parse_dockerfile(f)
					internals[f] = get_internal_duplicates(tmp)
					tmp.each do |command|
						if !externals[command]
							externals[command] = Set.new
						end
						externals[command].add(f)
					end
				rescue
					pp f
				end
			end
		end

		return internals, get_external_duplicates(externals)
	end

	def get_internal_duplicates(commands)
		commands.inject(Hash.new(0)) {|h,i| h[i] += 1; h }.to_a.sort {|a,b| b[1] <=> a[1]}
	end

	def get_external_duplicates(externals)
		tmp = {}
		externals.each do |k, v|
			tmp[k] = v.size
		end

		tmp.to_a.sort {|a,b| b[1] <=> a[1]}
	end

	def create_analysis_dir(path)
		FileUtils::mkdir_p path
	end
end
