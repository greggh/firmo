#!/usr/bin/env python3

import os
import re

def fix_multiple_blanks(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Replace multiple blank lines with a single blank line
    if file_path != 'CHANGELOG.md':
        content = re.sub(r'\n{2,}', '\n\n', content)

    with open(file_path, 'w') as file:
        file.write(content)

def process_directory(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.md'):
                file_path = os.path.join(root, file)
                print(f"Processing {file_path}")
                fix_multiple_blanks(file_path)

if __name__ == "__main__":
    process_directory('.')