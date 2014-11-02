#!/usr/bin/ruby
require_relative 'command_line_utility'
require 'optparse'

class CommandLineTool < CommandLineUtility
	@@command_format = ''
	@executing_file_name = ''

	def initialize(current_file)
		@executing_file_name = File.basename(current_file)

		check_arguments(OptionParser.new.parse(ARGV))
	end

	def check_arguments(arguments)
		arguments_given = arguments.length
		arguments_arity =  self.method(:run).arity

		if (arguments_given == arguments_arity)
			run(*arguments)
		else
			raise_arguments_error(arguments_arity, arguments_given)
		end
	end

	def run(); end

	def raise_arguments_error(arguments_arity, arguments_given)
		raise_error(
			"#{bold(red(@executing_file_name))} takes " +
			"#{bold(red(arguments_arity))} #{pluralize('arguement', arguments_arity)}. " +
			"#{bold(red(arguments_given))} given.\n" +
			"#{@executing_file_name} #{@@command_format}"
		)
	end

	def pluralize(string, count)
		return (count > 1) ?
			string + 's' :
			string
	end
end