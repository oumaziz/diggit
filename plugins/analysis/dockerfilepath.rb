require 'fileutils'
require 'json'
require 'pp'

class Dockerfilepath < Diggit::Analysis
	require_addons 'out'

	def initialize(options)
		super(options)
	end

	def run
		levels = []
		files = []
		path = out.out_path_for_analysis(self)

		init(levels, files)
		edits, co_evolution = get_edit_frequency_evolution()

		# We save everything
		create_analysis_dir(path)
		save_to_file("#{path}/count", files.length)
		save_to_file("#{path}/dockerfiles.json", JSON.pretty_generate(files))
		save_to_file("#{path}/levels.json", JSON.pretty_generate(levels))
		save_to_file("#{path}/frequency.json", JSON.pretty_generate(edits))
		save_to_file("#{path}/co_evolution.json", JSON.pretty_generate(co_evolution))
	end

	def save_to_file(filename, data)
		File.open(filename,"w") do |f|
      f.puts(data)
    end
	end

	def init(levels, files)
		levels.push({"platform" => 0, "OS" => 0, "version" => 0})

		Dir.chdir("#{@source.folder}") do
			files.concat(Dir["**/Dockerfile"])
			files.each do |f|

				split = f.split("/")[0...-1]

				for i in 0...split.size
					if levels.size < i + 2
						levels.push({"type" => "", "count" => 0, "values" => [], "actual" => [], "star" => [], "star_count" => 0})
					end

					levels[i+1]["values"].push(split[0..i].join("/"))
					levels[i+1]["actual"].push(split[i])
					levels[i+1]["count"] = levels[i+1]["values"].size

					if f.split("/")[i+1] == "Dockerfile"
						split[i] = "#{split[i]}*"
						levels[i+1]["star"].push(split[i])
						levels[i+1]["star_count"] = levels[i+1]["star"].size
					end
				end
			end

			for i in 1...levels.size
				levels[i]["uniq"] = levels[i]["actual"].uniq
				levels[i]["uniq_count"] = levels[i]["uniq"].size
				levels[i]["values"] = levels[i]["values"].uniq
				levels[i].delete("actual")
			end

			#pp levels
		end
	end

	def get_edit_frequency_evolution()
		commits = []
		co_evolution = []
		edits = {}

		# On recupere la liste des editions de Dockerfile
		walker = Rugged::Walker.new(repo)
		walker.sorting(Rugged::SORT_DATE | Rugged::SORT_REVERSE)
		walker.push(repo.head.target)
		walker.each do |commit|
			count = 0
			commit_files = []
			diff = commit.diff(paths: ["**/Dockerfile"])

			diff.each_delta{ |d|
				pp d
				next if d.status != :modified
				path = d.old_file[:path]

				if !edits[path]
					edits[path] = []
				end

				edits[path].push(commit.oid)
				count += 1
			}

			commit.tree.walk_blobs(:postorder) { |root, entry|
				if entry[:name] == "Dockerfile"
					commit_files.push("#{root}#{entry[:name]}")
					if !edits["#{root}#{entry[:name]}"]
						edits["#{root}#{entry[:name]}"] = []
					end
				end
			}

			if count >= 1
				co_evolution.push({commit: commit.oid,
													 count: count,
													 commit_files: commit_files,
													 percentage: count.to_f / commit_files.size.to_f * 100
				})
			end

			commits.push(commit)
		end

		# co_evolution.each { |e|
		# 	e[:percentage] = e[:count].to_f / edits.keys.size.to_f * 100
		# }

		#pp co_evolution
		# edits.each{ |k, v|
		# 	pp k => v.size
		# }

		#pp edits["2.7/slim/Dockerfile"]
		#pp edits["2.7/slim/Dockerfile"].size
		#pp edits["2.7/slim/Dockerfile"].uniq.size
		return edits, co_evolution
	end

	def create_analysis_dir(path)
		FileUtils::mkdir_p path
	end
end
