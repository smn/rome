require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'


task :default => :spec

desc "Run the specs with RSpec"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList["#{File.dirname(__FILE__)}/spec/*_spec.rb"]
  t.spec_opts = ["--colour", "--format specdoc"]
end


# namespace :test do
#   desc 'Measures test coverage'
#   task :coverage do
#     rm_f "coverage"
#     rm_f "coverage.data"
#     rcov = "rcov --aggregate coverage.data --text-summary --exclude test,^/"
#     system("#{rcov} --html test/*_spec.rb")
#   end
# end

# def flog(output, *directories)
#   system("find #{directories.join(" ")} -name \\*.rb | xargs flog")
# end

desc "Analyze code complexity."
task :flog do
  flog "lib", "lib"
end

desc "rdoc"
Rake::RDocTask.new('rdoc') do |rdoc|
    rdoc.rdoc_dir = 'doc'
    rdoc.title = 'Virginity vCard library'
    rdoc.options << '--line-numbers' << '--inline-source'
    #rdoc.rdoc_files.include("app/**/*.rb")
#     rdoc.main = 'README'
end



