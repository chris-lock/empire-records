#!/usr/bin/ruby

class CommandLineUtility
	def raise_error(message)
		puts(get_error(message))
	end

	def get_error(message)
		return "\a" + message + "\n"
	end

	def raise_fatal_error(message)
		abort(get_error(message))
	end

	def bold(string)
		return "\033[1m#{string}\033[22m"
	end

	def colorize(string, color_code)
		return "\e[#{color_code}m#{string}\e[0m"
	end

	def red(string)
		return colorize(string, 31)
	end

	def green(string)
		return colorize(string, 32)
	end

	def yellow(string)
		return colorize(string, 33)
	end

	def pink(string)
		return colorize(string, 35)
	end
end