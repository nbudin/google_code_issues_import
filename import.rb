require 'google_code'

reader = GoogleCode::IssueReader.new("procon")
puts reader.issues

