require 'rubygems'
require 'active_resource'

module TimetrapRedmine
    module API
        class Resource < ActiveResource::Base
            self.format = ActiveResource::Formats::XmlFormat
        end

        class Issue < Resource
        end

        class TimeEntry < Resource
        end
    end
end
