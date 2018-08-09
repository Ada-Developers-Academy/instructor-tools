#! /usr/bin/env ruby

# Installation
# $ ./fetch_project.rb --install

require 'csv'

INSTALL_TARGET = "/usr/local/bin/fetch_project"
USERNAME_FILE = "#{ENV['HOME']}/Ada/c10/usernames.csv"
SETUP_INSTRUCTIONS = <<END_INSTR
1. Copy the table from the repo view in the classroom app
2. Paste it into a file ~/Ada/cx/usernames.csv
3. Use Atom's regex search/replace to transform the data
    Search:  ^(.*) .*\\t(.*)\\t.*\\t.*Feedback\\t?$
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

def students
  keys = [:first_name, :username]
  return CSV.read(USERNAME_FILE).map { |a| Hash[keys.zip(a)] }
end

def check_for_error(status)
  if status.exitstatus != 0
    raise FetchProjectError, "Process exited with non-zero status code"
  end
end

def fetch_project(project, students)
  puts "Fetching submissions for #{project}"


  students.each do |student|
    puts "Fetching project for #{student[:first_name]}, account #{student[:username]}"

    puts `git remote add #{student[:first_name]} "https://github.com/#{student[:username]}/#{project}.git"`
    check_for_error($CHILD_STATUS)

    puts `git fetch #{student[:first_name]} || git remote remove $NAME`
    check_for_error($CHILD_STATUS)
  end
end

def install
  if File.exist?(INSTALL_TARGET)
    raise InstallationError, "Install target #{INSTALL_TARGET} already exists!"
  end

  puts "Installing to #{INSTALL_TARGET}"

  script_location = `realpath #{__FILE__}`.strip
  puts "Creating symlink pointing at #{script_location}"

  command = "ln -s #{script_location} #{INSTALL_TARGET}"
  puts "Creating symplink with command:\n  #{command}"
  puts `#{command}`

  if $CHILD_STATUS.exitstatus != 0
    raise InstallationError, "ln -s exited with non-0 status!"
  end
end

def check_setup
  if $PROGRAM_NAME.include?('.rb')
    puts "NOTE: it looks like you're running this file directly."
    puts "You might want to install it:"
    puts "    #{$PROGRAM_NAME} --install"
    sleep(2)
  end

  unless File.exist?(USERNAME_FILE)
    puts "Could not find list of usernames at #{USERNAME_FILE}"
    puts "In order to use this program, please follow these steps:"
    puts SETUP_INSTRUCTIONS
    raise InstallationError, "Improper setup"
  end
end

def main
  if ARGV[0] == "--install"
    install
  else
    check_setup
    fetch_project(project_name, students)
  end
end

main if $PROGRAM_NAME == __FILE__
