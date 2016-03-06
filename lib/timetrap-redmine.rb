require_relative './timetrap_redmine/api'

class Timetrap::Formatters::Redmine
    attr_reader :entries

    def initialize(entries)
        TimetrapRedmine::API::Resource.site     = Timetrap::Config['redmine']['url']
        TimetrapRedmine::API::Resource.user     = Timetrap::Config['redmine']['user']
        TimetrapRedmine::API::Resource.password = Timetrap::Config['redmine']['password']

        @entries = entries
    end

    def output
        status = Hash.new(0)
        entries.each {|e| status[process(e)] += 1}

        STDERR.puts " % 4d created"   % status[:created]
        STDERR.puts " % 4d updated"   % status[:updated]
        STDERR.puts " % 4d unchanged" % status[:unchanged]
        STDERR.puts " % 4d error(s)"  % status[:error]

        exit
    end

    private

    def process(entry)
        return unless match = /^([0-9]+)(?:\s+(.+?))?\s*$/.match(entry.note)

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

        redmine_entry = find_redmine_entry(prefix)

        return :unchanged if redmine_entry &&
                             redmine_entry.issue.id == time_entry[:issue_id] &&
                             redmine_entry.comments == time_entry[:comments] &&
                             redmine_entry.spent_on == time_entry[:spent_on] &&
                             ((redmine_entry.hours || '0.0').to_f - time_entry[:hours]).abs < 0.01

        begin
            issue = TimetrapRedmine::API::Issue.find(issue_id)
        rescue ActiveResource::ResourceNotFound
            STDERR.puts "Error: no such issue: #{issue_id}"
            return :error
        rescue ActiveResource::ForbiddenAccess
            STDERR.puts "Error: inaccessible issue: #{issue_id}"
            return :error
        end

        operation = redmine_entry ? :updated : :created

        line = "%s %s % 5.2f " % [
            operation == :updated ? 'upd' : 'add',
            time_entry[:spent_on],
            time_entry[:hours]
        ]
        line += "##{issue.id}: #{issue.subject}"[0, 80 - line.length]
        STDERR.puts(line)

        redmine_entry = TimetrapRedmine::API::TimeEntry.new unless redmine_entry
        redmine_entry.update_attributes(time_entry)

        return operation
    end

    def find_redmine_entry(prefix)
        TimetrapRedmine::API::TimeEntry.find(:all, :params => {
            :f     => ['comments', 'user_id'],
            :op    => {:comments => '~', 'user_id' => '='},
            :v     => {:comments => [prefix], 'user_id' => ['me']},
            :sort  => 'id',
        }).find {|e| e.comments.start_with?(prefix)}
    end
end
