require 'optparse'

class CommandLineTool
	@executing_file_name

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
			"#{bold(red(arguments_given))} given."
		)
	end

	def pluralize(string, count)
		return (count > 1) ? string + 's' : string
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

	def raise_error(message)
		puts(get_error(message))
	end

	def get_error(message)
		return "\a" + message + "\n"
	end

	def raise_fatal_error(message)
		abort(get_error(message))
	end
end