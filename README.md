# XcodeSortInstaller

A simple gem to install a new build phase on your Xcode project file to sort itself on build.

Keeps your `.xcodeproj` file sorted every time your target is built by using Apple's own sorting perl script as found in the [WebKit tools](https://github.com/adobe/webkit/blob/master/Tools/Scripts/sort-Xcode-project-file). A sorted project file will make merging project files slightly less painful since everything is not being appended to the end of a file list. This isn't a cure-all for Xcode project file merges, but helps.

## Installation

Add this line to your application's Gemfile:

    gem 'xcode_sort_install'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install xcode_sort_install

## Usage

If your .xcodeproj file is located in the root directory of your folder structure:

    $ xcode_sort_installer

If your .xcodeproj file is in another directory other than the source root:

Run in your subdirectory `SubFolder/ $ xcode_sort_installer -r ..` indicating that your source root is one directory below the current directory. If your project is not under version control or you don't care about adding our timestamp file to your .*ignore file, then you don't need to specify a root directory.

You can also explicitly specify both a project location and root location by using the `-p` and `-r` switches:

    SomeFolder/NotInProject/ $ xcode_sort_installer -p /project/root/subfolder/project.xcodeproj -r /project/root

Some other options:

``` lang:shell
-v, --[no-]verbose               Run verbosely
-p, --project PROJ               Location of .xcodeproj file
-r, --root-dir DIR               Root directory of project (Where .git or .svn folder lives)
-h, --help                       Show this message
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

##License

Standard MIT License
