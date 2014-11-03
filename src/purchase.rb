#!/usr/bin/ruby
require_relative 'command_line_tool'
require_relative 'inventory'

##
# Remove an items from inventory by their uid if it is valid.
#
# @param {string} uid The item to remove
#
class Purchase < CommandLineTool
	# @type {string} The format the tool expects commands in
	@@command_format = '[uid]'
	# @type {object} The inventory object
	@inventory

	##
	# Checks to see if the uid matches a product. If it does, we remove one.
	# Otherwise, we throw an error.
	#
	# @param {string} uid The uid of the product to remove
	# @returns {void}
	#
	def run(uid)
		@inventory = Inventory.new()
		product = @inventory.get(uid)

		return (product) ?
			remove_product(uid, product, 1) :
			raise_invalid_uid_error(uid)
	end
	##
	# Checks to see if the item is out of stock and that we have enough for the
	# given request. If so, we remove it, or else we throw a respective error.
	#
	# @param {string} uid The uid of the product to remove
	# @param {hash} product The product to remove
	# @param {int} quantity The quantity to remove
	# @returns {void}
	#
	def remove_product(uid, product, quantity)
		stock = product['Quantity']

		if (stock == 0)
			raise_error(
				"#{get_album_description(product)} " +
				"in #{get_product_format(product)} " +
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
	##
	# Gets the description of a product to output.
	#
	# @param {hash} product The product
	# @returns {string} The full product description
	#
	def get_product_description(product)
		return "#{get_product_format(product)} " +
			"of #{get_album_description(product)}"
	end
	##
	# Gets the description of an album to output.
	#
	# @param {hash} product The product
	# @returns {string} The album description
	#
	def get_album_description(product)
		return "#{bold(product['Title'])} " +
			"by #{bold(product['Artist'])}"
	end
	##
	# Gets the product format to output.
	#
	# @param {hash} product The product
	# @returns {string} The product format
	#
	def get_product_format(product)
		return "#{bold(product['Format'])}"
	end
	##
	# Raises an error for an invalid uid.
	#
	# @param {string} uid The uid of the product to remove
	# @returns {void}
	#
	def raise_invalid_uid_error(uid)
		raise_error("#{bold(uid)} is not a valid uid.")
	end
end
##
# Runs the purchase tool
#
Purchase.new(__FILE__)