#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'

class SearchInventory < CommandLineTool
	@@command_format = '[field name] [search]'
	@inventory

	def run(field_name, search)
		@inventory = Inventory.new()
		field_name = field_name.downcase

		return (@inventory.is_search_field(field_name)) ?
			search(field_name, search) :
			raise_invalid_field_name_error(field_name)
	end

	def search(field_name, search)
		results = @inventory.search(field_name, search)

		return (results.length > 0) ?
			show_results(results) :
			show_no_results(field_name, search)
	end

	def show_results(results)
		result_sets = get_grouped_results(results).collect do |matches, result_set|
			get_results(result_set)
		end

		puts(result_sets.join("\n\n"))
	end

	def get_grouped_results(results)
		return results.group_by do |result|
			[
				result['Artist'],
				result['Title'],
				result['ReleaseYear']
			]
		end
	end

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

	def show_no_results(field_name, search)
		puts("No matchs found for #{bold(search)} in #{bold(field_name)}.")
	end

	def raise_invalid_field_name_error(field_name)
		raise_error("#{bold(field_name)} is not a valid field name.")
	end
end

SearchInventory.new(__FILE__)