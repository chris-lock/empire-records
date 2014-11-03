#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'
require 'csv'

##
# Loads albums into inventory from a single file if the string provided is
# actually a file.
#
# @param {string} file_name The inventory file
#
class LoadInventory < CommandLineTool
	# @type {string} The format the tool expects commands in
	@@command_format = '[file]'
	# @type {string} The inventory file name
	@file_name = ''
	# @type {int} The current line being parsed
	@line_number = 1

	##
	# Loads an inventory file if the string provided is actually a file.
	#
	# @param {string} file_name The inventory file name
	# @returns {void}
	#
	def run(file_name)
		@file_name = file_name

		if (File.exists?(@file_name))
			parse_file()
		else
			raise_file_error()
		end
	end
	##
	# Parses the file based on it's extension if we support that file type.
	#
	# @returns {void}
	#
	def parse_file()
		file_extension = File.extname(@file_name)
		parse_method = file_extension.sub('.', 'parse_')

		if (self.respond_to?(parse_method))
			Inventory.new().add(
				self.send(parse_method)
			)
		else
			raise_file_type_error(file_extension)
		end
	end
	##
	# Parses a pipe delimited file with the format:
	# Quantity | Format | ReleaseYear | Artist | Title
	#
	# @returns {array} The albums in the file
	#
	def parse_pipe()
		return get_albums(
			File.open(@file_name),
			[
				'Quantity',
				'Format',
				'ReleaseYear',
				'Artist',
				'Title'
			],
			'parse_pipe_line'
		)
	end
	##
	# Strips the EOL character from the line and converts it to an array.
	#
	# @param {string} line The line from the pipe file
	# @returns {array} The values as an array
	#
	def parse_pipe_line(line)
		return line.strip().split(' | ')
	end
	##
	# Gets all the albums from the file, parsing each line, and mapping the
	# output to the array of labels to build a hash.
	#
	# @param {string} lines The lines in the file
	# @param {array} labels Labels that match the value order of the line
	# @param {string} parse_line_method The method to parse each line with
	# @returns {array} The albums with the proper key value pairs
	#
	def get_albums(lines, labels, parse_line_method)
		@line_number = 0

		return lines.collect do |line|
			@line_number += 1

			get_album(labels, self.send(parse_line_method, line))
		end
	end
	##
	# Maps the array of labels to the values of the line as an array after
	# checking that the line has enough values.
	#
	# @param {array} labels Labels that match the value order of the line
	# @param {array} values The line split into an array
	# @returns {hash} Key value pairs for the album
	#
	def get_album(labels, values)
		if (labels.length != values.length)
			raise_parse_error('Not enough values for album')
		end

		return(Hash[labels.zip(values)])
	end
	##
	# Raises a fatal error if parsing fails.
	#
	# @param {string} error The parse error
	# @returns {void}
	#
	def raise_parse_error(error)
		raise_fatal_error(
			"Cannot load #{bold(red(@file_name))}.\n" +
			"Error on #{bold(red('Line ' + @line_number.to_s))}: #{error}"
		)
	end
	##
	# Parses a csv with the format:
	# Artist,Title,Format,ReleaseYear
	# Quantity is reflected by duplicate rows.
	#
	# @returns {array} The albums in the file
	#
	def parse_csv()
		return get_albums_with_quantity(
			get_albums(
				CSV.parse(File.read(@file_name)),
				[
					'Artist',
					'Title',
					'Format',
					'ReleaseYear'
				],
				'parse_csv_line'
			)
		)
	end
	##
	# Since CSV.parse converts this to an array, we can just provided a pass
	# trough for uniformity.
	#
	# @param {array} line The line from the csv file
	# @returns {array} The values as an array
	#
	def parse_csv_line(line)
		return line
	end
	##
	# Rebuilds the albums array eliminating duplicates and adding the quantity.
	#
	# @param {string} albums The file calling the tool
	# @returns {array} The albums with the quantity
	#
	def get_albums_with_quantity(albums)
		grouped_albums = albums.group_by do |album|
			[
				album['Artist'],
				album['Title'],
				album['Format'],
				album['ReleaseYear']
			]
		end

		return grouped_albums.collect do |grouped_values, albums|
			album = albums[0]
			album['Quantity'] = albums.length.to_s

			album
		end
	end
	##
	# Raises an error when a file of an unsupported format is passed.
	#
	# @param {string} file_extension The file extension
	# @returns {void}
	#
	def raise_file_type_error(file_extension)
		raise_usage_error(
			"Sorry, #{bold(red(file_extension))} files are not supported."
		)
	end
	##
	# Raises an error when a string that is not a file is passed.
	#
	# @returns {void}
	#
	def raise_file_error()
		raise_usage_error(
			"#{bold(red(@file_name))} is not a file."
		)
	end
end
##
# Runs the load inventory tool
#
LoadInventory.new(__FILE__)