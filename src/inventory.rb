#!/usr/bin/ruby

require 'sqlite3'

class Inventory
	DB_NAME = 'inventory.db'
	@db

	def initialize

	end

	def add(albums)
		puts(albums)
	end

	def get(column, value)
		puts(column, value)
	end

	def remove(id)
		puts(id)
	end
end