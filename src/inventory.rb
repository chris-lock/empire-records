#!/usr/bin/ruby

require_relative 'command_line_utility'
require 'sqlite3'

class Inventory < CommandLineUtility
	CURRENT_DIR = File.expand_path(File.dirname(__FILE__))
	DB_PATH = CURRENT_DIR + '/inventory.db'
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
	SEARCH_HASH = {
		'id' => 'Id',
		'artist' => 'Artist',
		'title' => 'Title',
		'format' => 'Format',
		'release_year' => 'ReleaseYear',
		'quantity' => 'Quantity'
	}

	@db

	def initialize()
		return (!is_setup()) ?
			create_db() :
			open()
	end

	def is_setup()
		return (File.exists?(DB_PATH))
	end

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

	def open()
		if (!@db || @db.closed?)
			@db = SQLite3::Database.open(DB_PATH)
			@db.results_as_hash = true
		end

		return self
	end

	def execute_batch(statement, values = [])
		return db_send('execute_batch', statement, values)
	end

	def db_send(method, statement, values)
		result = @db.send(method, statement, values)

		rescue SQLite3::Exception => exception
			raise_fatal_error(
				"Exception occurred\n" +
				"#{exception}"
			)

		return result
	end

	def add(albums)
		open().add_quantity(get_albums_with_ids(albums))
		close()
	end

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

	def get_unique_albums(albums)
		unique_albums = albums.collect do |album|
			unique_album = album.clone

			unique_album.delete('Format')
			unique_album.delete('Quantity')

			unique_album
		end

		return unique_albums.uniq
	end

	def get_unique_artists(albums)
		unique_artists = albums.collect do |album|
			{'Artist' => album['Artist']}
		end

		return unique_artists.uniq
	end

	def get_artist_ids(artists)
		return get_item_ids(
			artists,
			'Artists',
			{
				'Artist' => [
					'Artist'
				]
			},
			'Artist',
			'ArtistId'
		)
	end

	def get_item_ids(items, table, column_hash, item_column, item_id)
		ids = {}

		items.each do |item|
			item_hash = get_item_hash(item, column_hash)

			id = get_item_id(table, item_hash, item_id)

			ids[item[item_column]] = (id.to_s.empty?) ?
				insert(table, get_insert_hash(item_hash)) :
				id
		end

		return ids
	end

	def get_item_hash(item, column_hash)
		item_hash = {}

		column_hash.each do |column, item_keys|
			item_hash[column] = item_keys.collect do |item_key|
				item[item_key]
			end
		end

		return item_hash
	end

	def get_item_id(table, item_hash, item_id)
		item = select(table, item_hash, item_id)

		return (item.length > 0) ?
			item[0][item_id] :
			''
	end

	def select(table, where_hash, select_columns = '*')
		return execute(
			"SELECT #{select_columns} " +
			"FROM #{table} " +
			"WHERE #{get_where_statement(where_hash)}",
			get_where_values(where_hash)
		)
	end

	def get_where_statement(where_hash)
		where_statement = where_hash.collect do |column, values|
			"#{column} in (#{get_execute_vars(values)})"
		end

		return where_statement.join(' AND ')
	end

	def get_execute_vars(columns)
		column_length = (columns.kind_of?(Array)) ?
			columns.length :
			1

		return (['?'] * column_length).join(',')
	end

	def get_where_values(where_hash)
		where_values = []

		where_hash.each do |key, values|
			where_values.concat(values)
		end

		return where_values
	end

	def execute(statement, values = [])
		return db_send('execute', statement, values)
	end

	def get_insert_hash(item_hash)
		insert_hash = {}

		item_hash.each do |key, values|
			insert_hash[key] = get_clean_insert_hash_value(key, values[0])
		end

		return insert_hash
	end

	def get_clean_insert_hash_value(key, value)
		if (key == 'Format')
			value = value.capitalize
		end

		return value
	end

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

	def get_album_ids(albums)
		return get_item_ids(
			albums,
			'Albums',
			{
				'Title' => [
					'Title'
				],
				'ArtistId' => [
					'Artist'
				],
				'ReleaseYear' => [
					'ReleaseYear'
				]
			},
			'Title',
			'AlbumId'
		)
	end

	def add_quantity(albums)
		column_hash = {
			'AlbumId' => [
				'Title'
			],
			'Format' => [
				'Format'
			]
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

	def update(table, update_hash, where_hash)
		return execute(
			"UPDATE #{table} " +
			"SET #{get_set_statement(update_hash)}" +
			"WHERE #{get_where_statement(where_hash)}",
			get_update_values([update_hash, where_hash])
		)
	end

	def get_set_statement(update_hash)
		set_statements = update_hash.collect do |column, value|
			"#{column} = ?"
		end

		return set_statements.join(',')
	end

	def get_update_values(hashes)
		return hashes.collect do |hash|
			hash.collect do |key, value|
				value
			end
		end
	end

	def close()
		if (!@db.closed?)
			@db.close()
		end
	end

	def get(id)
		inventory = open().get_inventory({'Id' => [id]})
		close()

		return (inventory && inventory.length > 0) ?
			inventory[0] :
			false
	end

	def get_inventory(where_hash)
		return select_all(
			get_where_statement(where_hash),
			get_where_values(where_hash)
		)
	end

	def select_all(where_statement, where_values)
		return execute(
			"SELECT #{SEARCH_HASH.values.join(',')} " +
			"FROM Artists " +
			"NATURAL JOIN Albums " +
			"NATURAL JOIN Inventory " +
			"WHERE #{where_statement}",
			where_values
		)
	end

	def remove(id, quantity)
		 open().execute(
			"UPDATE Inventory " +
			"SET Quantity = Quantity - ? " +
			"WHERE Id = ?",
			[quantity, id]
		)
		close()
	end

	def is_search_field(column)
		return SEARCH_HASH.has_key?(column)
	end

	def search(column, value)
		results = open().select_all(
			"#{column} like ? AND Quantity > 0",
			["%#{value}%"]
		)
		close()

		return results
	end
end