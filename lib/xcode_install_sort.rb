require "xcode_install_sort/version"
require 'Xcodeproj'
require 'fileutils'

module XcodeInstallSort
  class XcodeSortInstaller
    def install_sort_on_project(project_file_location, verbose)
      
      raise "File path not an xcodeproj!" unless File.basename(project_file_location).include?("xcodeproj")
      
      puts "Integrating sort script into targets in #{project_file_location}"

      proj = Xcodeproj::Project.new(project_file_location)

      proj.objects.each do |object|
        #What happens when a project has a sub-project?
        if object.class == Xcodeproj::Project::Object::PBXProject
          if process_project_object?(object, verbose)
            save_project(object, project_file_location, verbose)
          end
        end
      end
      
      append_gitignore(project_file_location)
    end
    
    def append_gitignore(project_file_path)
      directory = File.dirname(project_file_path)
      gitignore_path = "#{directory}/.gitignore"
      
      if File.readlines(gitignore_path).grep(/project_sort_last_run/).size == 0
        puts "Adding project sore timestamp file to gitignore"
        
        File.open(gitignore_path, 'a') do |f|
          f << "project_sort_last_run\n"
        end
      else
        puts "Gitignore already contains project sort timestamp file"
      end
    end
    
    def install_targets_from_project(project_object, verbose)

      script_targets = []

      project_object.targets.each do |potential_target|
        if potential_target.dependencies.count == 0
          puts "Target without dependencies: #{potential_target.name}" if verbose
          script_targets << potential_target unless script_targets.include?(potential_target)
        else
          puts "Target #{potential_target.name} has #{potential_target.dependencies.count} #{"dependency".pluralize(potential_target.dependencies.count)}" if verbose
          potential_target.dependencies.each do |dependency|
            puts "\tDependency: #{dependency.target}" if verbose
          end
        end
      end

      return script_targets
    end
    
    def process_project_object?(project, verbose)
      first_target = project.targets[0]

      script_targets = install_targets_from_project(project, verbose)

      script_targets.each do |target|
        add_sort_script_to_target(target, verbose)
      end
      
      puts "Successfully integrated sort phase to #{script_targets.count.to_s} #{"target".pluralize(script_targets.count)}.\n"
      
      return (script_targets.count > 0)
    end
    
    def add_sort_script_to_target(target, verbose)
      puts "Adding sort script to #{target} target" if verbose

      uuid = target.project.generate_uuid

      target_shell_script_text_path = included_file_path("sort-phase.sh")
      script_text = File.open(target_shell_script_text_path).read
      
      script = target.new_shell_script_build_phase("Sort Project File")
      script.shell_script = script_text
    end
    
    def included_file_path(file_name)
      t = ["#{File.dirname(File.expand_path($0))}/../lib/xcode_install_sort/#{file_name}",
        "#{Gem.dir}/gems/xcode_install_sort-#{XcodeInstallSort::VERSION}/lib/xcode_install_sort/#{file_name}"]
        t.each {|i| return i if File.readable?(i) }
      raise "both paths are invalid: #{t}"
    end
    
    def save_project(project, project_file_location, verbose)
      puts "Saving project file modifications..." if verbose
      
      base_folder = File.dirname(project_file_location)
      puts "Copying sort script to project location: #{base_folder}"
      FileUtils.cp included_file_path("sort-Xcode-project-file.pl"), "#{base_folder}/sort-Xcode-project-file.pl", :verbose => verbose

      if project.project.save_as(project_file_location)
        puts "The next time you build your project, your project file will sort itself. This *will* result in massive project-file changes. Coordinate with others on your team to ensure their versions of the project file are also sorted. It is advisable you commit these project file changes and new scripts into source control before making further changes."
        return true
      else
        puts "Error saving project file."
        return false
      end
    end
  end
end
