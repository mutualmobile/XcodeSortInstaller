require "xcode_install_sort/version"
require 'Xcodeproj'

module XcodeInstallSort
  
  INSTALL_SUCCESS_MSG = "The next time you build your project, your project file will sort itself. This *will* result in massive project-file changes. Coordinate with others on your team to ensure their versions of the project file are also sorted. It is advisable you commit these project file changes and new scripts into source control before making further changes."
  XCODE_SORT_SCRIPT_FILE_NAME = "sort-Xcode-project-file.pl"
  XCODE_SORT_PHASE_SCRIPT_FILE_NAME = "sort-phase.sh"
  XCODE_SORT_TIMESTAMP_FILE_NAME = "project_sort_last_run"
  XCODE_SORT_PHASE_NAME = "Sort Project File"
  XCODE_PROJ_EXTENSION = "xcodeproj"
  
  class XcodeSortInstaller
    attr_accessor :verbose
    attr_reader :project_file_location
    
    public
    def initialize(project_path)
      @project_file_location = project_path
      yield self if block_given?
    end
    
    def install!
      raise "File path not an xcodeproj!" unless File.basename(@project_file_location).include?(XCODE_PROJ_EXTENSION)
      
      puts "Integrating sort script into targets in #{@project_file_location}" if @verbose

      proj = Xcodeproj::Project.new(@project_file_location)
      proj.objects.each do |project|
        #What happens when a project has a sub-project?
        if project.class == Xcodeproj::Project::Object::PBXProject
          if process?(project)
            save_project(project)
          end
        end
      end
      
      append_gitignore
    end
    
    private
    def install_at_location!(project_file_location)
      @project_file_location = project_file_location
      install!
    end
    
    def append_gitignore
      directory = File.dirname(@project_file_location)
      gitignore_path = "#{directory}/.gitignore"
      
      add_gitignore_maybe(gitignore_path)
    end
    
    def add_gitignore_maybe(gitignore_path)
      if needs_gitignore_entry?(gitignore_path)
        puts "Adding project sort timestamp file to gitignore"
        
        File.open(gitignore_path, 'a') do |f|
          f << "#{XCODE_SORT_TIMESTAMP_FILE_NAME}\n"
        end
      else
        puts "Gitignore already contains project sort timestamp file exclusion" if @verbose
      end
    end
    
    def needs_gitignore_entry?(gitignore_path)
      gitignore_timestamp_matches = File.readlines(gitignore_path).grep(/project_sort_last_run/).size
      return (gitignore_timestamp_matches == 0)
    end
    
    def potential_targets(project)

      script_targets = []

      project.targets.each do |potential_target|
        if potential_target.dependencies.empty?
          puts "Target without dependencies: #{potential_target.name}" if @verbose
          script_targets << potential_target unless script_targets.include?(potential_target)
        elsif @verbose
          dependency_count = potential_target.dependencies.count
          puts "Target #{potential_target.name} has #{dependency_count} #{"dependency".pluralize(dependency_count)}"
          potential_target.dependencies.each do |dependency|
            puts "\tDependency: #{dependency.target}"
          end 
        end
      end

      return script_targets
    end
    
    def process?(project)
      script_targets = potential_targets(project)

      script_targets.each do |target|
        add_sort_script_to_target(target)
      end
      
      puts "Successfully integrated sort phase to #{script_targets.count.to_s} #{"target".pluralize(script_targets.count)}.\n"
      
      return !script_targets.empty?
    end
    
    def add_sort_script_to_target(target)
      puts "Adding sort script to #{target} target" if @verbose

      uuid = target.project.generate_uuid
      target_shell_script_text_path = included_file_path(XCODE_SORT_PHASE_SCRIPT_FILE_NAME)
      script_text = File.open(target_shell_script_text_path).read
      
      if !target_has_sort_script(target)
        script = target.new_shell_script_build_phase(XCODE_SORT_PHASE_NAME)
        script.shell_script = script_text
      end
    end
    
    def target_has_sort_script(target)
      # TODO: Implement sort script detection
      return false
    end
    
    def included_file_path(file_name)
      t = ["#{File.dirname(File.expand_path($0))}/../lib/#{XcodeInstallSort::NAME}/#{file_name}",
        "#{Gem.dir}/gems/#{XcodeInstallSort::NAME}-#{XcodeInstallSort::VERSION}/lib/#{XcodeInstallSort::NAME}/#{file_name}"]
        t.each {|i| return i if File.readable?(i) }
      raise "Both sort script paths are invalid: #{t}\nYou may have to reinstall this gem or check your load path."
    end
    
    def save_project(project)
      puts "Saving project file modifications..." if @verbose
      
      base_folder = File.dirname(@project_file_location)
      puts "Copying sort script to project location: #{base_folder}"
      FileUtils.cp included_file_path(XCODE_SORT_SCRIPT_FILE_NAME),
       "#{base_folder}/#{XCODE_SORT_SCRIPT_FILE_NAME}",
       :verbose => @verbose

      success = project.project.save_as(@project_file_location)
      
      if success
        puts INSTALL_SUCCESS_MSG
      else
        puts "Error saving project file." end
      
      return success
    end
  end
end
