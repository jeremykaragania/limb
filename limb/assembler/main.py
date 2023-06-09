#!/usr/bin/env python3

import sys
from collections import namedtuple

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

def assemble(filenames):
  messages = []
  for filename in filenames:
    try:
      open(filename, 'r')
    except FileNotFoundError:
      messages.append(assembler_message(None, None, "Error", f"can't open {filename}"))
      break
  return messages

def main():
  filenames = sys.argv[1:]
  messages = assemble(filenames)
  if messages:
    message_to_str = lambda message: ':'.join(message[2]) if message.file_name else "" + ": ".join(message[2:])
    message_strs = [message_to_str(i) for i in messages]
    print(f"Assembler messages:")
    print('\n'.join(messages_strs))

if __name__ == "__main__":
  main()
