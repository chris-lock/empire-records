#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'
require 'csv'

class LoadInventory < CommandLineTool
	@@command_format = '[file]'
	@file_name = ''
	@line_number = 1

	def run(file_name)
		@file_name = file_name

		if (File.exists?(@file_name))
			parse_file()
		else
			raise_file_error()
		end
	end

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

	def parse_pipe_line(line)
		return line.strip().split(' | ')
	end

	def get_albums(lines, labels, parse_line_method)
		@line_number = 0

		return lines.collect do |line|
			@line_number += 1

			get_album(
				labels,
				self.send(parse_line_method, line)
			)
		end
	end

	def get_album(labels, values)
		if (labels.length != values.length)
			raise_parse_error('Not enough values for album')
		end

		return(Hash[labels.zip(values)])
	end

	def raise_parse_error(error)
		raise_fatal_error(
			"Cannot load #{bold(red(@file_name))}.\n" +
			"Error on #{bold(red('Line ' + @line_number.to_s))}: #{error}"
		)
	end

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

	def parse_csv_line(line)
		return line
	end

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

	def raise_file_type_error(file_extension)
		raise_usage_error(
			"Sorry, #{bold(red(file_extension))} files are not supported."
		)
	end

	def raise_file_error()
		raise_usage_error(
			"#{bold(red(@file_name))} is not a file."
		)
	end
end

LoadInventory.new(__FILE__)