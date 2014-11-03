#!/usr/bin/ruby

##
# Base class for command line utilities that need basic output.
#
class CommandLineUtility
	##
	# Raises an error that sounds an alert.
	#
	# @param {string} message The error message
	# @returns {void}
	#
	def raise_error(message)
		puts(get_error(message))
	end
	##
	# Gets a string with an alert and line break.
	#
	# @param {string} message The error message
	# @returns {string} The message string with an alert and line break
	#
	def get_error(message)
		return "\a" + message + "\n"
	end
	##
	# Raises an error that sounds an alert and aborts.
	#
	# @param {string} message The error message
	# @returns {void}
	#
	def raise_fatal_error(message)
		abort(get_error(message))
	end
	##
	# Gets a bolded string.
	#
	# @param {string} string The string to bold
	# @returns {string} The bolded string
	#
	def bold(string)
		return "\033[1m#{string}\033[22m"
	end
	##
	# Gets a colorized string.
	#
	# @param {string} string The string to colorize
	# @param {string} color_code The color to use
	# @returns {string} The colorized string
	#
	def colorize(string, color_code)
		return "\e[#{color_code}m#{string}\e[0m"
	end
	##
	# Gets a red string.
	#
	# @param {string} string The string to colorize
	# @returns {string} The red string
	#
	def red(string)
		return colorize(string, 31)
	end
	##
	# Gets a green string.
	#
	# @param {string} string The string to colorize
	# @returns {string} The green string
	#
	def green(string)
		return colorize(string, 32)
	end
	##
	# Gets a yellow string.
	#
	# @param {string} string The string to colorize
	# @returns {string} The yellow string
	#
	def yellow(string)
		return colorize(string, 33)
	end
	##
	# Gets a pink string.
	#
	# @param {string} string The string to colorize
	# @returns {string} The pink string
	#
	def pink(string)
		return colorize(string, 35)
	end
end