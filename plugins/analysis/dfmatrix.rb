require 'pp'
require 'json'

class Dfmatrix < Diggit::Analysis
	require_addons 'out', 'src_opt'

	def initialize(options)
		super(options)
	end

	def run
    # Pour avoir un folder name avec le _
    #to_s.gsub(/[^[\w-]]+/, "_")

    puts @source.url
    source_length = src_opt[@source].length
    matrix = Array.new(source_length) { Array.new(source_length, []) }

    for i in 1...source_length
      for j in 0...i
        # Compute the similarity
        # save it in the matrix

        result = {}

        file1 = file_path(i)
        file2 = file_path(j)

        number_lines1 =  "wc -l < #{file1}"
        number_lines2 =  "wc -l < #{file2}"

        result["i_nb_lines"] = %x[ #{number_lines1} ].strip
        result["j_nb_lines"] = %x[ #{number_lines2} ].strip

        cmd = "diff #{file1} #{file2} | grep '\\(<\\|>\\)' | wc -l"
        result_diff = %x[ #{cmd} ].strip

        result["diff"] = result_diff

        result_sim = 100 - (result_diff.to_f / (%x[ #{number_lines1} ].to_f + %x[ #{number_lines2} ].to_f) * 100)

        result["sim"] = result_sim

        puts "[#{i},#{j}] diff: #{result_diff}, sim: #{result_sim}"

        matrix[i][j] = result
      end
    end

    File.open("/diggit/result/#{@source.id}.json","w") do |f|
      f.puts(matrix.to_json)
    end

    #puts matrix.to_json
	end

  def file_path(index)
    "#{@source.folder}/#{src_opt[@source][index]}"
  end

  def cmd_nb_lines(file)
    "wc -l < #{file}"
  end

	def clean
		out.clean
	end
end
