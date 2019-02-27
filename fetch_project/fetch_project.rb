#! /usr/bin/env ruby

# Installation
# $ ./fetch_project.rb --install

require 'csv'
require 'optparse'

# Tasty defaults - see parse_options below
INSTALL_TARGET = "/usr/local/bin/"
SCRIPT_NAME = 'fetch_project'
USERNAME_FILE = "#{ENV['HOME']}/Ada/c11/usernames.csv"

SETUP_INSTRUCTIONS = <<END_INSTR
1. Copy the table from the repo view in the classroom app
2. Paste it into a file ~/Ada/cx/usernames.csv
3. Use VS Code's search/replace to transform the data
    Search:  ^([^ ]*) .*\t([^:]*)\t(.*:.*\t)?.*(Feedback|Notification).*$
    Replace: $1,$2
END_INSTR

class FetchProjectError < StandardError; end
class InstallationError < StandardError; end



def project_name
  return ARGV[1] if ARGV[1]

  remotes = `git remote -v`.split("\n")
  remote = remotes.select { |r| r.start_with? "origin" }.first

  # HTTP style: https://github.com/Ada-C10/calculator.git
  # SSH style: git@github.com:Ada-C10/calculator.git
  # Search for ...github.com[:/].../<project name>.git...
  match = remote.match(%r{^.*github.com[:/][^/]+/(.*)\.git.*$})
  return match[1] if match

  raise FetchProjectError, "Could not detect project name. Are you in the project repo?"
end

def students(username_file)
  keys = [:first_name, :username]
  students = CSV.read(username_file).map { |a| Hash[keys.zip(a)] }
  puts "Read #{students.length} students from #{username_file}"
  return students
end

def fetch_project(project, students, options)
  puts "Fetching submissions for #{project}"

  students.each do |student|
    puts "Fetching project for #{student[:first_name]}, account #{student[:username]}"

    unless options[:dryrun]
      puts `git remote add #{student[:first_name]} "https://github.com/#{student[:username]}/#{project}.git"`
      if $CHILD_STATUS.exitstatus != 0
        puts "Could not add remote for student #{student[:first_name]}"
      end

      puts `git fetch #{student[:first_name]} || git remote remove $NAME`
      if $CHILD_STATUS.exitstatus != 0
        puts "Could not fetch repo for student #{student[:first_name]}"
      end
    end
  end
end

def install(install_location)
  if File.directory?(install_location)
    install_location = File.join(install_location, SCRIPT_NAME)
  end

  if File.exist?(install_location)
    raise InstallationError, "Install target #{install_location} already exists!"
  end

  puts "Installing to #{install_location}"

  script_location = `realpath #{__FILE__}`.strip
  puts "Creating symlink pointing at #{script_location}"

  command = "ln -s #{script_location} #{install_location}"
  puts "Creating symplink with command:\n  #{command}"
  puts `#{command}`

  if $CHILD_STATUS.exitstatus != 0
    raise InstallationError, "ln -s exited with non-0 status!"
  end

  puts "Installed successfully"
end

def check_setup(username_file)
  if $PROGRAM_NAME.include?('.rb')
    puts "NOTE: it looks like you're running this file directly."
    puts "You might want to install it:"
    puts "    #{$PROGRAM_NAME} --install"
    sleep(2)
  end

  unless File.exist?(username_file)
    puts "Could not find list of usernames at #{username_file}"
    puts "In order to use this program, please follow these steps:"
    puts SETUP_INSTRUCTIONS
    raise InstallationError, "Improper setup"
  end
end

def parse_options
  options = {
    install_location: INSTALL_TARGET,
    username_file: USERNAME_FILE
  }
  OptionParser.new do |parser|
    parser.banner = "Usage: fetch_project.rb [options]"

    parser.on("--install [LOCATION]", "Install this script") do |install_location|
      options[:install] = true
      if install_location
        options[:install_location] = install_location
      end
    end
    parser.on("--usernames LOCATION", "Username file location") do |location|
      options[:username_file] = location
    end
    parser.on("--dryrun", "Print work, but don't actually fetch projects") do
      options[:dryrun] = true
    end
  end.parse!
  return options
end

def main
  options = parse_options
  if options[:install]
    puts "installing to #{options[:install_location]}"
    install(options[:install_location])
  else
    check_setup(options[:username_file])
    student_list = students(options[:username_file])
    fetch_project(project_name, student_list, options)
  end
end

main if $PROGRAM_NAME == __FILE__
