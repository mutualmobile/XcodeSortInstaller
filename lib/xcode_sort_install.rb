require "xcode_sort_install/version"
require 'Xcodeproj'
require 'colored'

module XcodeSortInstall
  
  MSG_INSTALL_SUCCESS = "\nSuccess!\nThe next time you build your project, your project file will sort itself. This *will* initially result in massive project-file changes. This is not the case on subsequent builds. Coordinate with others on your team to ensure their versions of the project file are also sorted. It is advisable you commit these project file changes and new scripts into source control before making further changes.\n\nFrom now on when building your project, your project file will sort itself automagically, hopefully making project file merges a little less painful.\n"
  MSG_NO_VALID_TARGETS = "\nNo project targets modified. It looks like your project has no valid targets for modification."
  MSG_TARGETS_ALREADY_SETUP = "\nNo project targets modified. These targets may have already been setup to use the sort script."
  MSG_ERROR_SAVING_TO_DISK = "Error saving project file to disk."
  MSG_ADDING_GITIGNORE_ENTRY = "Adding project sort timestamp file to gitignore\n"
  MSG_GITIGNORE_EXISTS = "Gitignore already contains project sort timestamp file exclusion\n"
  MSG_NOT_XCODEPROJ = "File path not an xcodeproj!"
  XCODE_SORT_SCRIPT_FILE_NAME = "sort-Xcode-project-file.pl"
  XCODE_SORT_PHASE_SCRIPT_FILE_NAME = "sort-phase.sh"
  XCODE_SORT_TIMESTAMP_FILE_NAME = "project_sort_last_run"
  XCODE_SORT_PHASE_NAME = "XcodeProjectSortPhase"
  XCODE_PROJ_EXTENSION = "xcodeproj"
  GITIGNORE_ENTRY = "#{XCODE_SORT_TIMESTAMP_FILE_NAME}\n"
  
  class XcodeSortInstaller
    attr_accessor :verbose
    attr_reader :project_file_location
    attr_accessor :root_dir
    
    public
    def initialize(project_path)
      @project_file_location = project_path
      yield self if block_given?
    end
    
    def install!
      raise "#{MSG_NOT_XCODEPROJ} #{@project_file_location}".bold.red unless File.basename(@project_file_location).include?(XCODE_PROJ_EXTENSION)
      
      puts "Analyzing targets in #{@project_file_location}...\n".bold.green if @verbose

      proj = Xcodeproj::Project.new(@project_file_location)
      proj.objects.each do |project|
        #What happens when a project has a sub-project?
        if project.class == Xcodeproj::Project::Object::PBXProject
          if process?(project)
            append_gitignore #TODO: What about .svnignore?
            save_project(project)
          end
        end
      end
    end
    
    private
    def install_at_location!(project_file_location)
      @project_file_location = project_file_location
      install!
    end
    
    def append_gitignore
      if @root_dir
        puts "Using root directory: #{@root_dir}"
        add_gitignore_maybe("#{@root_dir}/.gitignore")
      else
        puts "Using project directory: #{@project_file_location}"
        directory = File.dirname(@project_file_location)
        add_gitignore_maybe("#{directory}/.gitignore")
      end
    end
    
    def add_gitignore_maybe(gitignore_path)
      if needs_gitignore_entry?(gitignore_path)
        puts MSG_ADDING_GITIGNORE_ENTRY.bold.green

        File.open(gitignore_path, 'a') do |f|
          f << GITIGNORE_ENTRY
        end
      elsif !File.exists?(gitignore_path)
        puts "Automatic detection of .gitignore file failed. Please manually add the file \"#{XCODE_SORT_TIMESTAMP_FILE_NAME}\" to your gitignore.".red
      else
        puts MSG_GITIGNORE_EXISTS.yellow if @verbose
      end
    end
    
    def needs_gitignore_entry?(gitignore_path)
      if File.exists?(gitignore_path)
        gitignore_timestamp_matches = File.readlines(gitignore_path).grep(/project_sort_last_run/).size
        return (gitignore_timestamp_matches == 0)
      end
    end
    
    def potential_targets(project)

      script_targets = []

      project.targets.each do |potential_target|
        if potential_target.dependencies.empty?
          puts "Target without dependencies: #{potential_target.name.bold}".green if @verbose
          script_targets << potential_target unless script_targets.include?(potential_target)
        elsif @verbose
          dependency_count = potential_target.dependencies.count
          puts "Target #{potential_target.name} has #{dependency_count} #{"dependency".pluralize(dependency_count)}".bold.yellow
          potential_target.dependencies.each do |dependency|
            puts "\tDependency: #{dependency.target}".yellow
          end 
        end
        
        if target_has_sort_script?(potential_target) && @verbose
          puts "\tTarget #{potential_target.name} has preexisting sort script!".yellow
        end
        
      end

      return script_targets
    end
    
    def process?(project)
      script_targets = potential_targets(project)

      installed_targets = []
      
      if !script_targets.empty? && @verbose
        puts "\nFound #{script_targets.count} potential #{"target".pluralize(script_targets.count)}".bold.green
      end

      script_targets.each do |target|
        installed_targets << target if add_sort_script_to_target(target)
      end
      
      if installed_targets.empty? && !script_targets.empty?
        puts MSG_TARGETS_ALREADY_SETUP.yellow
      elsif script_targets.empty?
        puts MSG_NO_VALID_TARGETS.yellow
      else
        puts "Successfully integrated sort phase to #{installed_targets.count.to_s} #{"target".pluralize(installed_targets.count)}.\n".bold.green
      end
      
      return !installed_targets.empty?
    end
    
    def add_sort_script_to_target(target)
      uuid = target.project.generate_uuid
      target_shell_script_text_path = included_file_path(XCODE_SORT_PHASE_SCRIPT_FILE_NAME)
      script_text = File.open(target_shell_script_text_path).read
      
      if !target_has_sort_script?(target)
        puts "Adding sort script to target #{target.display_name.bold.green}".green if @verbose
        
        script = target.new_shell_script_build_phase(XCODE_SORT_PHASE_NAME)
        script.shell_script = script_text
        
        return true
      end
    end
    
    def target_has_sort_script?(target)
      target.build_phases.each do |phase|
        if phase.display_name.include?(XCODE_SORT_PHASE_NAME)
          return true
        end
      end
      
      return false
    end
    
    def included_file_path(file_name)
      t = [
        "#{File.dirname(File.expand_path($0))}/../lib/#{XcodeSortInstall::NAME}/#{file_name}",
        "#{Gem.dir}/gems/#{XcodeSortInstall::NAME}-#{XcodeSortInstall::VERSION}/lib/#{XcodeSortInstall::NAME}/#{file_name}"
        ]
        t.each { |i|
          return i if File.readable?(i)
        }
      raise "Both sort script paths are invalid: #{t}\nYou may have to reinstall this gem or check your load path.".bold.red
    end
    
    def save_project(project)
      puts "Saving project file modifications...".green if @verbose
      
      base_folder = File.dirname(@project_file_location)
      puts "Copying sort script to project location: #{base_folder}"
      script_file_path = "#{base_folder}/#{XCODE_SORT_SCRIPT_FILE_NAME}"
      puts "Script file path: #{script_file_path}"
      puts "Destination path: #{included_file_path(XCODE_SORT_SCRIPT_FILE_NAME)}"
      FileUtils.copy(included_file_path(XCODE_SORT_SCRIPT_FILE_NAME), script_file_path, :verbose => @verbose)
       
      if !File.executable?(script_file_path)
        
        # sort_script = File.open(script_file_path,"w")
        File.chmod(0777, script_file_path)
      end

      success = project.project.save_as(@project_file_location)
      
      if success
        puts MSG_INSTALL_SUCCESS.bold.green
      else
        puts MSG_ERROR_SAVING_TO_DISK.bold.red end
      
      return success
    end
  end
end
