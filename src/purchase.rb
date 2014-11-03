#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'

class Purchase < CommandLineTool
	@@command_format = '[uid]'
	@inventory

	def run(uid)
		@inventory = Inventory.new()
		product = @inventory.get(uid)

		return (product) ?
			remove_product(uid, product, 1) :
			raise_invalid_uid_error(uid)
	end

	def remove_product(uid, product, quantity)
		if (product)
			stock = product['Quantity']

			if (stock == 0)
				raise_error(
					"#{get_album_description(product)} " +
					"in #{get_product_type(product)} " +
					"is out of stock."
				)
			elsif (stock < quantity)
				raise_error(
					"The are not #{bold(quantity)} " +
					"#{get_product_description(product)} " +
					"in stock."
				)
			else
				@inventory.remove(uid, quantity)
				puts(
					"Removed #{bold(quantity)} " +
					"#{get_product_description(product)} " +
					"from the inventory."
				)
			end
		end
	end

	def get_product_description(product)
		return "#{get_product_type(product)} " +
			"of #{get_album_description(product)}"
	end

	def get_album_description(product)
		return "#{bold(product['Title'])} " +
			"by #{bold(product['Artist'])}"
	end

	def get_product_type(product)
		return "#{bold(product['Format'])}"
	end

	def raise_invalid_uid_error(uid)
		raise_error("#{bold(uid)} is not a valid uid.")
	end
end

Purchase.new(__FILE__)