# timetrap-redmine

This gem provides a Timetrap formatter `redmine` that can be used to push
timelog entries to corresponding Redmine issues.

## Installation

    $ gem install timetrap-redmine

    $ mkdir -p ~/.timetrap/formatters
    $ echo "require 'timetrap-redmine'" > /path/to/formatters/redmine.rb

## Configuration

~/.timetrap.yml:

    ---
    redmine:
        url:      http://example.com/redmine
        user:     abcde
        password: fghij

You can either use your username and password, or specify your API key in `user`
and omit `password`.

## Usage

The formatter expects timelog entry notes to start with the issue number. In
addition you can add comments that will also be added to the entry in Redmine.

    $ t i 4
    $ t d -fredmine

To sync all your timesheets up until 7 days ago:

    $ t d all -fredmine -s'7 days ago'

The Redmine time entry will be prefixed with `[tt 123]` where `123` is the ID of
the Timetrap entry. This is done to be able to retrieve and update Redmine
entries later on.

When you change an entry after syncing, it will be updated in Redmin. However,
if you remove an entry, it will _not_ be synced to Redmine. You can try setting
the duration to 0:

    $ t e -s 12:00 -e 12:00
