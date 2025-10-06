import re

with open('lib/screens/modern_profile_screen.dart', 'r') as f:
    content = f.read()

# Count all opening and closing braces
open_braces = len(re.findall(r'\{', content))
close_braces = len(re.findall(r'\}', content))

open_parens = len(re.findall(r'\(', content))
close_parens = len(re.findall(r'\)', content))

print(f'Total opening braces: {open_braces}')
print(f'Total closing braces: {close_braces}')
print(f'Total opening parentheses: {open_parens}')
print(f'Total closing parentheses: {close_parens}')

# Check for structures in strings
string_matches = re.findall(r'[\'\"](.*?)[\'\"]', content, re.DOTALL)
structures_in_strings = 0
for match in string_matches:
    structures_in_strings += len(re.findall(r'[\{\}\(\)]', match))

print(f'Structures in strings: {structures_in_strings}')

# The actual structural elements should be total minus those in strings
actual_open_braces = open_braces - (structures_in_strings // 2)  # Approximate
actual_close_braces = close_braces - (structures_in_strings // 2)  # Approximate

print(f'Approximate actual opening braces: {actual_open_braces}')
print(f'Approximate actual closing braces: {actual_close_braces}')
