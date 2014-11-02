#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'
require 'csv'

class LoadInventory < CommandLineTool
	@file_name
	@line_number = 1

	def run(file_name)
		@file_name = file_name

		if File.exists?(@file_name)
			parse_file()
		else
			raise_file_error()
		end
	end

	def parse_file()
		file_extension = File.extname(@file_name)
		parse_method = file_extension.sub('.', 'parse_')

		if self.respond_to?(parse_method)
			Inventory.new.add(
				send(parse_method)
			)
		else
			raise_file_type_error(file_extension)
		end
	end

	def parse_pipe()
		return get_albums(
			File.open(@file_name),
			[
				'quanitity',
				'format',
				'release_year',
				'artist',
				'title'
			],
			'parse_pipe_line'
		)
	end

	def parse_pipe_line(line)
		return line.split('|')
	end

	def get_albums(lines, labels, parse_line_method)
		albums = []
		@line_number = 1

		lines.each do |line|
			albums.push(
				get_album(
					labels,
					send(parse_line_method, line)
				)
			)

			@line_number += 1
		end

		return albums
	end

	def get_album(labels, values)
		if (labels.length != values.length)
			raise_parse_error('Not enough values for album')
		end

		stripped_values = []

		values.each do |value|
			stripped_values.push(value.strip)
		end

		return(Hash[labels.zip(stripped_values)])
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
					'artist',
					'title',
					'format',
					'release_year'
				],
				'parse_csv_line'
			)
		)
	end

	def parse_csv_line(line)
		return line
	end

	def get_albums_with_quantity(albums)
		albums_with_quantity = []

		grouped_ablums = albums.group_by do |album|
			[
				album['artist'],
				album['title'],
				album['format']
			]
		end

		grouped_ablums.each do |grouped_values, albums|
			album = albums[0]
			album['quanitity'] = albums.length.to_s

			albums_with_quantity.push(album)
		end

		return albums_with_quantity
	end

	def raise_file_type_error(file_extension)
		raise_error(
			"Sorry, #{bold(red(file_extension))} files are not supported."
		)
	end

	def raise_file_error()
		raise_error(
			"#{bold(red(@file_name))} is not a file."
		)
	end
end

LoadInventory.new(__FILE__)