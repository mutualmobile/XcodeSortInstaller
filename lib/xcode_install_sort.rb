require "xcode_install_sort/version"
require 'Xcodeproj'
require 'fileutils'

module XcodeInstallSort
  class XcodeSortInstaller
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
    
    def install_sort_on_project(project_file_location, verbose)
      puts "Integrating sort script into targets in #{project_file_location}"

      proj = Xcodeproj::Project.new(project_file_location)

      proj.objects.each do |object|

        #What happens when a project has a sub-project?
        if object.class == Xcodeproj::Project::Object::PBXProject
          first_target = object.targets[0]

          script_targets = install_targets_from_project(object, verbose)

          if (script_targets.count > 0)
            base_folder = File.dirname(project_file_location)
            puts "Copying sort script to project location: #{base_folder}"
            FileUtils.cp "sort-Xcode-project-file.pl", "#{base_folder}/sort-Xcode-project-file.pl", :verbose => verbose
          end

          puts "Current directory: #{Dir.pwd}"

          script_text = File.open("#{Dir.pwd}/sort-phase.sh").read

          script_targets.each do |target|
            puts "Adding sort script to #{target} target" if verbose

            uuid = object.project.generate_uuid

            script = target.new_shell_script_build_phase("Sort Project File")
            script.shell_script = script_text
          end

          puts "Saving project file modifications..." if verbose

          if object.project.save_as(project_file_location)
            puts "Successfully integrated sort phase to #{script_targets.count.to_s} #{"target".pluralize(script_targets.count)}.\n"
            puts "The next time you build your project, your project file will sort itself. This *will* result in massive project-file changes. Coordinate with others on your team to ensure their versions of the project file are also sorted. It is advisable you commit these project file changes and new scripts into source control before making further changes."
          else
            puts "Error saving project file."
          end
        end
      end
    end
    
  end
end
