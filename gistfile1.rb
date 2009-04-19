require 'open-uri'
require 'csv'
require 'ostruct'

require 'rubygems'
require 'hpricot'

module GoogleCode
  class IssueReader
    DEBUG = true
    CSV_COLUMNS = %w(ID Type Component Status Priority Summary Modified Milestone Owner Stars Opened Closed BlockedOn Blocking Blocked MergedInto Reporter Cc)
  
    def initialize(project)
      @base_url = "http://code.google.com/p/#{project}/issues"
    end
  
    def read
      @issues = read_csv
      @issues.each do |id,issue|
        issue.merge!(read_extra_issue_details(id))
      end
    end
    
    def issues
      @issues ||= read
    end
  
    #protected
  
    def read_extra_issue_details(id)
      puts "Reading issue details for issue #{id}"
      
      issue = {}
      issue_doc = Hpricot(read_path("detail?id=#{id}"))
      issue[:description] = issue_doc.search("//td.issuedescription/pre").inner_html
      
      issue[:comments] = []
      issue_doc.search('//td.issuecomment/.author/..').each do |comment|
        issue[:comments] << {
          :author => comment.search('.author/a:last').inner_html,
          :body => comment.search('pre').inner_html,
          :time => DateTime.parse(comment.search('.date').first.attributes['title'])
        }
      end
      
      issue[:labels] = []
      issue_doc.search('//a.label').each do |label|
        next if CSV_COLUMNS.include?(label.search('b').inner_html[0..-2])
        issue[:labels] << label.inner_text
      end
      
      issue
    end
  
    def read_csv
      path = "csv?can=1&sort=id&colspec=#{CSV_COLUMNS.join('+')}"
      puts "Reading CSV file" if DEBUG
      
      issues = {}
      CSV.parse(read_path(path)) do |row|
        next if row[0] == 'ID'
        
        issue = {}
        row.each_with_index do |field,i|
          issue[GoogleCode::Support::underscore(CSV_COLUMNS[i]).to_sym] = field.to_s.empty? ? nil : \
            case CSV_COLUMNS[i]
            when 'ID', 'Stars', 'MergedInto'
              field.to_i
            when 'Component', 'Cc'
              field.to_s.split(',').map{|m| m.strip}
            when 'Opened', 'Closed', 'Modified'
              DateTime.parse(field.to_s)
            when 'Blocked'
              field.to_s == "Yes"
            else
              field.to_s
            end
          issues[row[0].to_i] = issue
        end
      end
      
      return issues
    end
    
    # Reads data from a path relative to the base Google Code URL 
    # for the project's issues.
    def read_path(path)
      url = "#{@base_url}/#{path}"
      puts "Fetching URL: #{url}" if DEBUG
      
      begin
        open(url).read
      rescue OpenURI::HTTPError => e
        puts "HTTP Error: #{e}"
        return ""
      end
    end
    
  end
  
  module Support
    def self.underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
  
end
