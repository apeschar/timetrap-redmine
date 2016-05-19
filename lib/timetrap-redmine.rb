require 'thread'

require_relative './timetrap_redmine/api'

class Timetrap::Formatters::Redmine
    attr_reader :entries

    def initialize(entries)
        TimetrapRedmine::API::Resource.site     = Timetrap::Config['redmine']['url']
        TimetrapRedmine::API::Resource.user     = Timetrap::Config['redmine']['user']
        TimetrapRedmine::API::Resource.password = Timetrap::Config['redmine']['password']

        @entries = entries

        threads = []

        threads << Thread.new do
            @issues = {}
            TimetrapRedmine::API::Issue.find(:all, :params => {
                :f     => ['status'],
                :op    => [:status => '*'],
                :sort  => 'id:desc',
                :limit => 100,
            }).each do |i|
                @issues[i.id] = i
            end
        end

        threads << Thread.new do
            @rm_entries = TimetrapRedmine::API::TimeEntry.find(:all, :params => {
                :f     => ['comments', 'user_id'],
                :op    => {:comments => '~', 'user_id' => '='},
                :v     => {:comments => ['[tt '], 'user_id' => ['me']},
                :sort  => 'id:desc',
                :limit => 100,
            })
        end

        threads.each(&:join)
    end

    def output
        status = Hash.new(0)
        entries.each {|e| status[process(e)] += 1}

        STDERR.puts "" if status.length

        STDERR.puts "error unchanged created updated"
        STDERR.puts "%5d %9d %7d %7d" % [status[:error], status[:unchanged], status[:created], status[:updated]]

        if status[:error] > 0
            exit 1
        else
            exit
        end
    end

    private

    def process(entry)
        unless match = /^([0-9]+)(?:\s+(.+?))?\s*$/.match(entry.note)
            STDERR.puts "Error: not an issue number: #{entry.note}"
            return :error
        end

        issue_id = match[1]
        comments = match[2] || ''

        prefix = "[tt #{entry.id}]"

        info = entry.end ? '' : ' (incomplete)'

        time_entry = {
            :issue_id => issue_id,
            :comments => "#{prefix}#{info} #{comments}",
            :spent_on => entry.start.strftime("%Y-%m-%d"),
            :hours    => entry.duration / 3600.0,
        }

        redmine_entry = find_entry(prefix)

        begin
            issue = find_issue(issue_id)
        rescue ActiveResource::ResourceNotFound
            STDERR.puts "Error: no such issue: #{issue_id}"
            return :error
        rescue ActiveResource::ForbiddenAccess
            STDERR.puts "Error: inaccessible issue: #{issue_id}"
            return :error
        end

        if redmine_entry &&
           redmine_entry.issue.id == time_entry[:issue_id] &&
           redmine_entry.comments == time_entry[:comments] &&
           redmine_entry.spent_on == time_entry[:spent_on] &&
           ((redmine_entry.hours || '0.0').to_f - time_entry[:hours]).abs < 0.01
            operation = :unchanged
        elsif redmine_entry
            operation = :updated
        else
            operation = :created
        end

        line = "% 3s %s % 5.2f " % [
            {:unchanged => '', :updated => 'upd', :created => 'add'}[operation],
            time_entry[:spent_on],
            time_entry[:hours]
        ]
        line += "##{issue.id}: #{issue.subject}"[0, 80 - line.length]
        STDERR.puts(line)

        unless operation == :unchanged
            redmine_entry = TimetrapRedmine::API::TimeEntry.new unless redmine_entry
            redmine_entry.update_attributes(time_entry)
        end

        return operation
    end

    def find_entry(prefix)
        match = lambda {|e| e.comments.start_with?(prefix)}

        @rm_entries.find(&match) || TimetrapRedmine::API::TimeEntry.find(:all, :params => {
            :f     => ['comments', 'user_id'],
            :op    => {:comments => '~', 'user_id' => '='},
            :v     => {:comments => [prefix], 'user_id' => ['me']},
            :sort  => 'id',
        }).find(&match)
    end

    def find_issue(issue_id)
        return @issues[issue_id] ||= TimetrapRedmine::API::Issue.find(issue_id)
    end
end
