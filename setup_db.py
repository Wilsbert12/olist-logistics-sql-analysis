import csv
import sqlite3
import os

# Connecting to the database
connection = sqlite3.connect('olist.sqlite')

# Creating a cursor object to execute
# SQL queries on a database table
cursor = connection.cursor()

# Table Definition

directory = 'data'

for file in os.listdir(directory):
    if file.endswith(".csv"):
        # Creating the tables into our database
        with open(f'data/{file}') as f:
                headers = next(csv.reader(f))
        columns = ', '.join(f'{col} TEXT' for col in headers)
        table_name = file.removesuffix('.csv')
        create_table = f'CREATE TABLE {table_name} ({columns})'
        cursor.execute(create_table)
        # Inserting content into the tables
        with open(f'data/{file}') as f:
            contents = csv.reader(f)
            next(contents)
            insert_records = f'INSERT INTO {table_name} VALUES ({", ".join(["?" for _ in headers])})'
            cursor.executemany(insert_records, contents)

# Committing the changes
connection.commit()

print('Database created successfully')

# closing the database connection
connection.close()