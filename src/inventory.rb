#!/usr/bin/ruby

require_relative 'command_line_utility'
require 'sqlite3'

class Inventory < CommandLineUtility
	CURRENT_DIR = File.expand_path(File.dirname(__FILE__))
	DB_PATH = CURRENT_DIR + '/inventory.db'
	DB_TABLES = {
		'Artists' => [
			'Id INTEGER PRIMARY KEY AUTOINCREMENT',
			'Name VARCHAR COLLATE NOCASE UNIQUE'
		],
		'Albums' => [
			'Id INTEGER PRIMARY KEY AUTOINCREMENT',
			'ArtistId INTEGER',
			'Name VARCHAR COLLATE NOCASE',
			'ReleaseYear INTEGER'
		],
		'Inventory' => [
			'Id INTEGER PRIMARY KEY AUTOINCREMENT',
			'AlbumId INTEGER',
			'Format VARCHAR COLLATE NOCASE',
			'Quantity INTEGER'
		]
	}

	@db
	@search_map = {
		'artist' => {
			'Artists' => 'Name'
		},
		'title' => {
			'Albums' => 'Name'
		},
		'format' => {
			'Inventory' => 'Format'
		},
		'release_year' => {
			'Albums' => 'ReleaseYear'
		},
		'id' => {
			'Inventory' => 'Id'
		}
	}

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
	end

	def open()
		@db = SQLite3::Database.open(DB_PATH)
		@db.results_as_hash = true

		return self
	end

	def execute_batch(statement, values = [])
		return db_send('execute_batch', statement, values)
	end

	def db_send(method, statement, values)
		puts statement, values, ''
		result = @db.send(method, statement, values)

		rescue SQLite3::Exception => exception
			raise_fatal_error(
				"Exception occurred\n" +
				"#{exception}"
			)

		return result
	end

	def add(albums)
		add_quantity(get_albums_with_ids(albums))

		close()
	end

	def get_albums_with_ids(albums)
		unique_albums = get_unique_albums(albums)
		artist_ids = get_artist_ids(
			get_unique_artists(unique_albums)
		)
		album_ids = get_album_ids(
			replace_album_keys(
				unique_albums,
				[
					{'artist' => artist_ids}
				]
			)
		)

		return replace_album_keys(
			albums,
			[
				{'artist' => artist_ids},
				{'title' => album_ids}
			]
		)
	end

	def get_unique_albums(albums)
		unique_albums = albums.collect do |album|
			unique_album = album.clone

			unique_album.delete('format')
			unique_album.delete('quantity')

			unique_album
		end

		return unique_albums.uniq
	end

	def get_unique_artists(albums)
		unique_artists = albums.collect do |album|
			{'artist' => album['artist']}
		end

		return unique_artists.uniq
	end

	def get_artist_ids(artists)
		return get_item_ids(
			artists,
			'Artists',
			{
				'Name' => [
					'artist'
				]
			},
			'artist'
		)
	end

	def get_item_ids(items, table, map, item_column)
		ids = {}

		items.each do |item|
			item_hash = get_item_hash(item, map)

			id = get_item_id(table, item_hash)

			ids[item[item_column]] = (id.to_s.empty?) ?
				insert_item(table, get_insert_hash(item_hash)) :
				id
		end

		return ids
	end

	def get_item_hash(item, map)
		item_hash = {}

		map.each do |map_key, item_keys|
			item_hash[map_key] = []

			item_keys.each do |item_key|
				item_hash[map_key].push(item[item_key])
			end
		end

		return item_hash
	end

	def get_item_id(table, item_hash)
		item = select_item(table, item_hash, 'Id')

		return (item.length > 0) ?
			item[0]['Id'] :
			''
	end

	def select_item(table, where_hash, select_columns = '*')
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
			insert_hash[key] = values[0]
		end

		return insert_hash
	end

	def insert_item(table, insert_hash)
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
				'Name' => [
					'title'
				],
				'ArtistId' => [
					'artist'
				],
				'ReleaseYear' => [
					'release_year'
				]
			},
			'title'
		)
	end

	def add_quantity(albums)
		album_map = {
			'AlbumId' => [
				'title'
			],
			'Format' => [
				'format'
			]
		}

		albums.each do |album|
			album_hash = get_item_hash(album, album_map)
			inventory = select_item('Inventory', album_hash, 'Quantity')

			insert_or_update_inventory(
				inventory,
				get_insert_hash(album_hash),
				album['quantity'].to_i
			)
		end
	end

	def insert_or_update_inventory(inventory, album_insert_hash, quantity)
		if (inventory && inventory.length > 0)
			album_update_hash = {
				'Quantity' => quantity + inventory[0]['Quantity']
			}

			update_item('Inventory', album_update_hash, album_insert_hash)
		else
			album_insert_hash['Quantity'] = quantity
			insert_item('Inventory', album_insert_hash)
		end
	end

	def update_item(table, update_hash, where_hash)
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
		if (@db)
			@db.close()
		end
	end

	def get(column, value)
		puts(column, value)
	end

	def remove(id)
		puts(id)
	end
end