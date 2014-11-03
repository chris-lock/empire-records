#!/usr/bin/ruby
require_relative 'command_line_utility'
require 'optparse'

##
# Base class for command line tools that accept parameters and output results.
#
class CommandLineTool < CommandLineUtility
	# @type {string} The format the tool expects commands in
	@@command_format = ''
	# @type {string} The file executing the tool
	@executing_file_name =''

	##
	# The initialize method sets the executing file and checks the arguments.
	#
	# @param {string} current_file The file calling the tool
	# @returns {void}
	#
	def initialize(current_file)
		@executing_file_name = File.basename(current_file)

		check_arguments(OptionParser.new.parse(ARGV))
	end
	##
	# Checks the number arguments passed against the number of arguments
	# required by the run method.
	#
	# @param {array} arguments The arguments from the command line
	# @returns {void}
	#
	def check_arguments(arguments)
		arguments_given = arguments.length
		arguments_arity =  self.method(:run).arity

		if (arguments_given == arguments_arity)
			run(*arguments)
		else
			raise_arguments_error(arguments_arity, arguments_given)
		end
	end
	##
	# Run method overwritten by sub clases.
	#
	# @returns {void}
	#
	def run()
	end
	##
	# Raises an error when the wrong number of arguments are given to the tool.
	#
	# @param {int} arguments_arity The number of arguments needed
	# @param {int} arguments_given The number of arguments given
	# @returns {void}
	#
	def raise_arguments_error(arguments_arity, arguments_given)
		raise_usage_error(
			"#{bold(red(@executing_file_name))} takes " +
			"#{bold(red(arguments_arity))} #{pluralize('arguement', arguments_arity)}. " +
			"#{bold(red(arguments_given))} given."
		)
	end
	##
	# Raises an error for inaccurate usage.
	#
	# @param {string} message The error message
	# @returns {void}
	#
	def raise_usage_error(error)
		raise_error(get_usage_error_message(error))
	end
	##
	# Gets an error message with the command format.
	#
	# @param {string} message The error message
	# @returns {string} The error plus the command format
	#
	def get_usage_error_message(error)
		return "#{error}\n" +
			"#{@executing_file_name} #{@@command_format}"
	end
	##
	# Raises an error for inaccurate usage and aborts.
	#
	# @param {string} message The error message
	# @returns {void}
	#
	def raise_fatal_usage_error(error)
		raise_fatal_error(get_usage_error_message(error))
	end
	##
	# Gets the basic plural or non plural version of a string based on a given
	# count.
	#
	# @param {string} string The string to plural
	# @param {string} count The count to base the plural on
	# @returns {string} The plural or non plural string
	#
	def pluralize(string, count)
		return (count > 1) ?
			string + 's' :
			string
	end
end