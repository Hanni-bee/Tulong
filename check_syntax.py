import re

# Read the file
with open('lib/screens/modern_profile_screen.dart', 'r') as f:
    content = f.read()

# Count braces and parentheses
open_braces = content.count('{')
close_braces = content.count('}')
open_parens = content.count('(')
close_parens = content.count(')')

print(f'Opening braces: {open_braces}')
print(f'Closing braces: {close_braces}')
print(f'Opening parentheses: {open_parens}')
print(f'Closing parentheses: {close_parens}')

# Check for unmatched structures
if open_braces != close_braces:
    print(f'Brace mismatch: {open_braces - close_braces} more opening braces')
if open_parens != close_parens:
    print(f'Parenthesis mismatch: {open_parens - close_parens} more opening parentheses')
