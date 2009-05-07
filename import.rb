require 'google_code'
require 'octopi/lib/octopi'
include Octopi

if ARGV.length < 2
  puts "Usage: import.rb <google-code-project> <github-project>"
  exit 1
end

reader = GoogleCode::IssueReader.new("procon")
issues = reader.issues

authenticated do |g|
  repo = g.repository(ARGV[1])
  issues.each do |id, issue|
    next if id == 0

    puts "Importing issue #{id}"
    
    gh_body = issue[:description]
    gh_body << "\n\nReported by #{issue[:reporter]} at #{issue[:opened].strftime("%Y-%m-%d %H:%M:S")}"
    gh_body << "Imported from Google Code issue number #{id}"
    gh_issue = repo.open_issue :title => issue[:summary], :body => gh_body

    gh_labels = issue[:labels].dup
    if issue[:type] and issue[:type].strip.length > 0
      gh_labels.push(issue[:type].downcase)
    end
    if issue[:milestone] and issue[:milestone].strip.length > 0
      gh_labels.push(issue[:milestone].downcase)
    end
    gh_issue.add_label(*gh_labels)

    issue[:comments].each do |comment|
      gh_comment = comment[:body]
      gh_comment << "\n\n-- #{comment[:author]}, #{comment[:time].strftime("%Y-%m-%d %H:%M:%S")}"
      gh_issue.comment(gh_comment)
    end

    if issue[:status] == "Fixed"
      gh_issue.close
    end
  end
end
