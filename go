#!/bin/sh
bundle check || bundle install
bundle exec rake $@
