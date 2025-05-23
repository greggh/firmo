#!/usr/bin/env python3

import os
import re

def fix_table_formatting(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Find all tables in the file
    tables = re.findall(r'(?<=\n)\|.*?\|(?:\n\|.*?\|)*?(?=\n)', content, re.DOTALL)

    for table in tables:
        # Add a blank line before and after the table
        table_with_blanks = '\n' + table + '\n'
        content = content.replace(table, table_with_blanks)

    with open(file_path, 'w') as file:
        file.write(content)

def process_directory(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.md'):
                file_path = os.path.join(root, file)
                print(f"Processing {file_path}")
                fix_table_formatting(file_path)

if __name__ == "__main__":
    process_directory('docs/api/formatters')