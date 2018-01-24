
class Dock < Diggit::Analysis

	def initialize(options)
		super(options)
	end

	def run

    puts @source.folder
    files = Dir["#{@source.folder}/**/Dockerfile"]

    File.open("/diggit/result/#{@source.id}","w") do |f|
      f.puts(files.length)
    end
	end
end
