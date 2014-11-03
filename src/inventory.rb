#!/usr/bin/ruby

require_relative 'command_line_utility'
require 'sqlite3'

##
# A class to manage the storage, retrieval, and removal of inventory items.
#
class Inventory < CommandLineUtility
	# @constant The path to the database in this files directory
	DB_PATH = File.expand_path(File.dirname(__FILE__)) + '/inventory.db'
	# @constant The table structure for the database
	DB_TABLES = {
		'Artists' => [
			'ArtistId INTEGER PRIMARY KEY AUTOINCREMENT',
			'Artist VARCHAR COLLATE NOCASE UNIQUE'
		],
		'Albums' => [
			'AlbumId INTEGER PRIMARY KEY AUTOINCREMENT',
			'ArtistId INTEGER',
			'Title VARCHAR COLLATE NOCASE',
			'ReleaseYear INTEGER'
		],
		'Inventory' => [
			'Id INTEGER PRIMARY KEY AUTOINCREMENT',
			'AlbumId INTEGER',
			'Format VARCHAR COLLATE NOCASE',
			'Quantity INTEGER'
		]
	}
	# @constant the map of search field names to columns
	SEARCH_HASH = {
		'id' => {
			'column' => 'Id',
			'order' => 'ASC'
		},
		'artist' => {
			'column' => 'Artist',
			'order' => 'ASC'
		},
		'title' => {
			'column' => 'Title',
			'order' => 'ASC'
		},
		'format' => {
			'column' => 'Format',
			'order' => 'DESC'
		},
		'release_year' => {
			'column' => 'ReleaseYear',
			'order' => 'DESC'
		},
		'quantity' => {
			'column' => 'Quantity',
			'order' => 'ASC'
		}
	}

	# @type {object} The sqlite database
	@db

	##
	# Checks if we've set up a database and builds it if we haven't.
	#
	# @return {void}
	#
	def initialize()
		return (!is_setup()) ?
			create_db() :
			open()
	end
	##
	# Checks if we've set up a database.
	#
	# @return {bool} The database is setup
	#
	def is_setup()
		return (File.exists?(DB_PATH))
	end
	##
	# Creates a database.
	#
	# @return {void}
	#
	def create_db()
		tables = []

		DB_TABLES.each do |table, columns|
			tables.push(
				"CREATE TABLE IF NOT EXISTS #{table} (#{columns.join(',')})"
			)
		end

		open().execute_batch(tables.join(';'))
		close()
	end
	##
	# Opens a database connection if one isn't already open.
	#
	# @return {object} The object for chaining
	#
	def open()
		if (!@db || @db.closed?)
			@db = SQLite3::Database.open(DB_PATH)
			@db.results_as_hash = true
		end

		return self
	end
	##
	# Executes multiple statements provided in a single string.
	#
	# @param {string} statement The statement to execute
	# @param {array} values The values to substitute
	# @return {array} The response for the execute_batch
	#
	def execute_batch(statement, values = [])
		return db_send('execute_batch', statement, values)
	end
	##
	# A wrapper for executing sqlite lite methods and rescuing exceptions.
	#
	# @param {string} method The sqlite method to execute
	# @param {string} statement The statement to execute
	# @param {array} values The values to substitute
	# @return {void}
	#
	def db_send(method, statement, values)
		result = @db.send(method, statement, values)

		rescue SQLite3::Exception => exception
			raise_fatal_error(
				"Exception occurred\n" +
				"#{exception}"
			)

		return result
	end
	##
	# Closes the database connection if we have one.
	#
	# @return {void}
	#
	def close()
		if (!@db.closed?)
			@db.close()
		end
	end
	##
	# Adds an array of albums to the inventory.
	#
	# @param {array} albums The albums to add
	# 		{hash} The album
	#			Artist
	#			Title
	#			Format
	#			ReleaseYear
	# 			Quantity
	# @return {void}
	#
	def add(albums)
		open().add_quantity(get_albums_with_ids(albums))
		close()
	end
	##
	# Gets the albums with the artist id and album id substituted for their
	# respective values to be used in updating the inventory table. We have to
	# work our way out from artists to albums since the latter will need the ids
	# from the prior.
	#
	# @param {array} albums The albums to get ids for
	# 		{hash} The album
	#			Artist
	#			Title
	#			Format
	#			ReleaseYear
	# 			Quantity
	# @return {array} The albums with the proper ids substituted
	# 		{hash} The album
	#			Artist => ArtistId
	#			Title => AlbumId
	#			Format
	#			ReleaseYear
	# 			Quantity
	#
	def get_albums_with_ids(albums)
		unique_albums = get_unique_albums(albums)
		artist_ids = get_artist_ids(get_unique_artists(unique_albums))
		album_ids = get_album_ids(
			replace_album_keys(
				unique_albums,
				[
					{'Artist' => artist_ids}
				]
			)
		)

		return replace_album_keys(
			albums,
			[
				{'Artist' => artist_ids},
				{'Title' => album_ids}
			]
		)
	end
	##
	# Gets the unique albums since duplicates will exists for formats.
	#
	# @param {array} albums All the albums
	# 		{hash} The album
	#			Artist
	#			Title
	#			Format
	#			ReleaseYear
	# 			Quantity
	# @return {array} The unique albums
	# 		{hash} The album
	#			Artist
	#			Title
	#			ReleaseYear
	#
	def get_unique_albums(albums)
		unique_albums = albums.collect do |album|
			unique_album = album.clone

			unique_album.delete('Format')
			unique_album.delete('Quantity')

			unique_album
		end

		return unique_albums.uniq
	end
	##
	# Gets the unique artists since duplicates will exists for albums.
	#
	# @param {array} albums All the albums
	# 		{hash} The album
	#			Artist
	#			Title
	#			ReleaseYear
	# @return {array} The unique artists
	# 		{hash} The album
	#			Artist
	#
	def get_unique_artists(albums)
		unique_artists = albums.collect do |album|
			{'Artist' => album['Artist']}
		end

		return unique_artists.uniq
	end
	##
	# Gets the ids for the artists.
	#
	# @param {array} artists The unique artists
	# 		{hash} The album
	#			Artist
	# @return {hash} The artist ids
	# 		Artist => ArtistId
	#
	def get_artist_ids(artists)
		return get_item_ids(
			artists,
			'Artists',
			{
				'Artist' => 'Artist'
			},
			'Artist',
			'ArtistId'
		)
	end
	##
	# Gets the ids for an set of items.
	#
	# @param {array} items
	# 		{hash} The item values
	# @param {string} table The table to query
	# @param {array} column_hash A map of the column names to the item keys
	# 		column name => item key
	# @param {array} item_name_column The column for the item name
	# @param {array} item_id_column The column for the item id
	# @return {hash} The items ids
	# 		item name =>  item id
	#
	def get_item_ids(items, table, column_hash, item_name_column, item_id_column)
		ids = {}

		items.each do |item|
			item_hash = get_item_hash(item, column_hash)

			id = get_item_id(table, item_hash, item_id_column)

			ids[item[item_name_column]] = (id.to_s.empty?) ?
				insert(table, get_insert_hash(item_hash)) :
				id
		end

		return ids
	end
	##
	# Gets a hash of column names to an array containing the item value. The
	# array is unnecessary but expected by the select method.
	#
	# @param {hash} item The item
	# @param {array} column_hash A map of the column names to the item keys
	# 		column name => item key
	# @return {hash} The map of column names to item values
	# 		column name => [item value]
	#
	def get_item_hash(item, column_hash)
		item_hash = {}

		column_hash.each do |column, item_key|
			item_hash[column] = [item[item_key]]
		end

		return item_hash
	end
	##
	# Gets the item id if it exists.
	#
	# @param {string} table The table to query
	# @param {hash} item_hash The map of column names to item values
	# 		column name => [item value]
	# @param {array} item_id_column The column for the item id
	# @return {int|string} The item id or empty string if not found
	#
	def get_item_id(table, item_hash, item_id_column)
		item = select(table, item_hash, item_id_column)

		return (item.length > 0) ?
			item[0][item_id_column] :
			''
	end
	##
	# Selects a given set of columns from a given table based on a array of
	# values for a set of columns. The where hash
	# 	{
	# 		'a' => [1, 2],
	# 		'b' => [3, 4]
	# 	}
	# would produce the where statement
	# 	WHERE a in (1, 2) AND b in (3, 4)
	#
	# @param {string} table The table to query
	# @param {hash} where_hash The map of column names to values
	# 		column name => [value, value]
	# @param {string} select_columns The columns to select
	# @return {hash}
	#
	def select(table, where_hash, select_columns = '*')
		return execute(
			"SELECT #{select_columns} " +
			"FROM #{table} " +
			"WHERE #{get_where_statement(where_hash)}",
			get_where_values(where_hash)
		)
	end
	##
	# Gets a where statement with ? substitutions based on a array of values for
	# a set of columns. The where hash
	# 	{
	# 		'a' => [1, 2],
	# 		'b' => [3, 4]
	# 	}
	# would produce the where statement
	# 	WHERE a in (?, ?) AND b in (?, ?)
	#
	# @param {hash} where_hash The map of column names to values
	# 		column name => [value, value]
	# @return {string} the where statement with ? substitutions
	#
	def get_where_statement(where_hash)
		where_statement = where_hash.collect do |column, values|
			"#{column} in (#{get_execute_vars(values)})"
		end

		return where_statement.join(' AND ')
	end
	##
	# Gets the right number of ? for the number of variables.
	#
	# @param {array|string} columns An array of values or string
	# @return {string} The right number of ? for the number of variables
	#
	def get_execute_vars(columns)
		column_length = (columns.kind_of?(Array)) ?
			columns.length :
			1

		return (['?'] * column_length).join(',')
	end
	##
	# Gets all the where values that need to be passed as bind_vars.
	#
	# @param {hash} where_hash The map of column names to values
	# 		column name => [value, value]
	# @return {array} The array of values to substitute
	#
	def get_where_values(where_hash)
		where_values = []

		where_hash.each do |key, values|
			where_values.concat(values)
		end

		return where_values
	end
	##
	# Executes a single statement.
	#
	# @param {string} statement The statement to execute
	# @param {array} values The values to substitute
	# @return {array} The response for the execute
	#
	def execute(statement, values = [])
		return db_send('execute', statement, values)
	end
	##
	# Converts the key array pair to a clean key value pair for the item.
	#
	# @param {hash} item_hash The map of column names to item values
	# 		column name => item value
	# @return {hash} The key value pair of column and item value
	#
	def get_insert_hash(item_hash)
		insert_hash = {}

		item_hash.each do |key, values|
			insert_hash[key] = get_clean_insert_hash_value(key, values[0])
		end

		return insert_hash
	end
	##
	# Runs formating for specific keys if they're present.
	#
	# @param {string} key The item key
	# @param {mixed} value The item value for that key
	# @return {mixed} The clean item value
	#
	def get_clean_insert_hash_value(key, value)
		if (key == 'Format')
			value = value.capitalize
		end

		return value
	end
	##
	# Inserts a row to the given table based on the key value pair of column
	# name and column value.
	#
	# @param {string} table The table to query
	# @param {hash} insert_hash The key value pair of column and value
	# @return {int} The inserted row id
	#
	def insert(table, insert_hash)
		columns = insert_hash.keys

		execute(
			"INSERT INTO #{table} " +
			"(#{columns.join(',')}) " +
			"VALUES (#{get_execute_vars(columns)})",
			insert_hash.values
		)

		return @db.last_insert_row_id
	end
	##
	# Replaces values in the albums array with the replacements provided.
	#
	# @param {array} albums The albums
	# @param {hash} replacements The pair of album key and replacements
	# 		albums key => key value pair of current and replacement
	# @return {array} The albums with replacements
	#
	def replace_album_keys(albums, replacements)
		albums.each do |album|
			replacements.each do |replacement|
				replacement.each do |key, value|
					album[key] = value[album[key]]
				end
			end
		end

		return albums
	end
	##
	# Gets the ids for the albums.
	#
	# @param {array} albums The unique albums
	# 		{hash} The album
	#			Artist
	# @return {hash} The artist ids
	# 		Artist => ArtistId
	#
	def get_album_ids(albums)
		return get_item_ids(
			albums,
			'Albums',
			{
				'Title' => 'Title',
				'ArtistId' => 'Artist',
				'ReleaseYear' => 'ReleaseYear'
			},
			'Title',
			'AlbumId'
		)
	end
	##
	# Checks to see if the album format is already in inventory, and then insets
	# or updates the quantities for the albums.
	#
	# @param {array} albums the albums with the proper ids substituted
	# @return {void}
	#
	def add_quantity(albums)
		column_hash = {
			'AlbumId' => 'Title',
			'Format' => 'Format'
		}

		albums.each do |album|
			album_hash = get_item_hash(album, column_hash)
			inventory = select('Inventory', album_hash, 'Quantity')

			insert_or_update_inventory(
				inventory,
				get_insert_hash(album_hash),
				album['Quantity'].to_i
			)
		end
	end
	##
	# Checks to see if there was any inventory. Updates if there was. Otherwise,
	# it inserts it.
	#
	# @param {array} inventory The inventory if any
	# @param {hash} album_insert_hash The key value pair of column and album value
	# @param {int} quantity The quantity we're adding
	# @return {void}
	#
	def insert_or_update_inventory(inventory, album_insert_hash, quantity)
		if (inventory && inventory.length > 0)
			album_update_hash = {
				'Quantity' => quantity + inventory[0]['Quantity']
			}

			update('Inventory', album_update_hash, album_insert_hash)
		else
			album_insert_hash['Quantity'] = quantity
			insert('Inventory', album_insert_hash)
		end
	end
	##
	# Updates the given table with a key value pair based on the match of
	# another key value pair.
	#
	# @param {string} table The table to update
	# @param {hash} update_hash The pair of column and value to update
	# @param {hash} where_hash The pair of column and value to match
	# @return {void}
	#
	def update(table, update_hash, where_hash)
		execute(
			"UPDATE #{table} " +
			"SET #{get_set_statement(update_hash)}" +
			"WHERE #{get_where_statement(where_hash)}",
			get_update_values([update_hash, where_hash])
		)
	end
	##
	# Gets the the correct number of where statements for the given hash.
	#
	# @param {hash} update_hash The pair of column and value to update
	# @return {string} The set statement
	#
	def get_set_statement(update_hash)
		set_statements = update_hash.collect do |column, value|
			"#{column} = ?"
		end

		return set_statements.join(',')
	end
	##
	# Takes all the values from the update_hash and where_hash to combine them
	# into a single array in the proper order.
	#
	# @param {array} hashes An array containing the update_hash and where_hash in order
	# @return {array} The update values
	#
	def get_update_values(hashes)
		return hashes.collect do |hash|
			hash.collect do |key, value|
				value
			end
		end
	end
	##
	# Gets an album based on it's uid.
	#
	# @param {string} uid The uid to look for
	# @return {hash|bool} The album or false if not found
	#
	def get(id)
		inventory = open().get_inventory({'Id' => [id]})
		close()

		return (inventory && inventory.length > 0) ?
			inventory[0] :
			false
	end
	##
	# Gets albums based on the where hash provided.
	#
	# @param {hash} where_hash The key value pairs of column value for the where statement
	# @return {array} The albums found
	#
	def get_inventory(where_hash)
		return select_all(
			get_where_statement(where_hash),
			get_where_values(where_hash)
		)
	end
	##
	# Gets all the values for an album using a natural join.
	#
	# @param {string} where_statement The where statement to use
	# @param {string} where_values The values to substitute in the where statement
	# @param {string} order_by_statment The optional order_by statement to use
	# @return {array} The albums found
	#
	def select_all(where_statement, where_values, order_by_statment = '')
		columns = SEARCH_HASH.collect do |field_name, properties|
			properties['column']
		end

		return execute(
			"SELECT #{columns.join(',')} " +
			"FROM Artists " +
			"NATURAL JOIN Albums " +
			"NATURAL JOIN Inventory " +
			"WHERE #{where_statement} " +
			"#{order_by_statment}",
			where_values
		)
	end
	##
	# Removes a given from of albums based on a given uid
	#
	# @param {string} id The uid for the album
	# @param {int} quantity The quantity to remove
	# @return {void}
	#
	def remove(id, quantity)
		 open().execute(
			"UPDATE Inventory " +
			"SET Quantity = Quantity - ? " +
			"WHERE Id = ?",
			[quantity, id]
		)
		close()
	end
	##
	# Checks if a field_name is a valid search field
	#
	# @param {string} field_name The field_name to check
	# @return {bool} The field_name is a valid search field
	#
	def is_search_field(field_name)
		return SEARCH_HASH.has_key?(field_name)
	end
	##
	# Searches a given field_name for a given value using fuzzy search.
	#
	# @param {string} field_name The field_name to search
	# @param {string} value The value to search for
	# @return {array} The matches found
	#
	def search(field_name, value)
		search_field = SEARCH_HASH[field_name]
		column = search_field['column']

		results = open().select_all(
			"#{column} like ? AND Quantity > 0",
			["%#{value}%"],
			"ORDER BY #{column} #{search_field['order']}"
		)
		close()

		return results
	end
	##
	# Gets all the valid search fields.
	#
	# @return {array} The search fields
	#
	def get_search_fields()
		return SEARCH_HASH.keys
	end
end