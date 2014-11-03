#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'

##
# Searches the inventory to match a string against a given column if that column
# exists
#
# @param {string} field_name The column to search
# @param {string} search The string to search for
#
class SearchInventory < CommandLineTool
	# @type {string} The format the tool expects commands in
	@@command_format = '[field name] [search]'
	# @type {object} The inventory object
	@inventory

	##
	# Checks to see if the the filed name exists. If it does, we search for the
	# term. Otherwise, we throw an error.
	#
	# @param {string} field_name The column to search
	# @param {string} search The string to search for
	# @returns {void}
	#
	def run(field_name, search)
		@inventory = Inventory.new()
		field_name = field_name.downcase

		return (@inventory.is_search_field(field_name)) ?
			search(field_name, search) :
			raise_invalid_field_name_error(field_name)
	end
	##
	# Runs the search for the term and shows the results or a no results message
	# if none were found.
	#
	# @param {string} field_name The column to search
	# @param {string} search The string to search for
	# @returns {void}
	#
	def search(field_name, search)
		results = @inventory.search(field_name, search)

		return (results.length > 0) ?
			show_results(results) :
			show_no_results(field_name, search)
	end
	##
	# Prints out the matches for the search formated:
	# Artist: <artist name>
	# Album: <album title>
	# Released: <release year>
	# <Format>(<format quantity>): <format inventory identifier>
	# <Format>(<format quantity>): <format inventory identifier>
	#
	# @param {array} results The albums that matched the search results
	# @returns {void}
	#
	def show_results(results)
		result_sets = get_grouped_results(results).collect do |matches, result_set|
			get_results(result_set)
		end

		puts(result_sets.join("\n\n"))
	end
	##
	# Groups the results by album.
	#
	# @param {array} results The albums that matched the search results
	# @returns {hash} A group_by hash formated [matched values] => [items]
	#
	def get_grouped_results(results)
		return results.group_by do |result|
			[
				result['Artist'],
				result['Title'],
				result['ReleaseYear']
			]
		end
	end
	##
	# Gets a result for the set of album formats found.
	#
	# @param {array} result_set The group of formats for the album
	# @returns {string} An album in result format
	#
	def get_results(result_set)
		album = result_set[0]
		formats = result_set.collect do |result|
			"#{result['Format']}(#{result['Quantity']}): #{result['Id']}"
		end

		return "Artist: #{album['Artist']}\n" +
			"Album: #{album['Title']}\n" +
			"Released: #{album['ReleaseYear']}\n" +
			formats.join("\n")
	end
	##
	# Prints a message for no results.
	#
	# @param {string} field_name The column to search
	# @param {string} search The string to search for
	# @returns {void}
	#
	def show_no_results(field_name, search)
		puts("No matches found for #{bold(search)} in #{bold(field_name)}.")
	end
	##
	# Raises an error for an invalid column name.
	#
	# @param {string} field_name The column to search
	# @returns {void}
	#
	def raise_invalid_field_name_error(field_name)
		raise_error("#{bold(field_name)} is not a valid field name.")
	end
end

SearchInventory.new(__FILE__)