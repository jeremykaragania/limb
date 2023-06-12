#!/usr/bin/env python3

import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

instruction_conditions = {
  "eq": 0b0000,
  "ne": 0b0001,
  "cs": 0b0010,
  "cc": 0b0011,
  "mi": 0b0100,
  "pl": 0b0101,
  "vs": 0b0110,
  "vc": 0b0111,
  "hi": 0b1000,
  "ls": 0b1001,
  "ge": 0b1010,
  "lt": 0b1011,
  "gt": 0b1100,
  "le": 0b1101,
  "al": 0b1110
}

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(instruction_conditions)})?"

def assemble(filenames):
  messages = []
  for filename in filenames:
    try:
      f = list(open(filename, 'r'))
    except FileNotFoundError:
      messages.append(assembler_message(None, None, "Error", f"can't open {filename}"))
      break
    else:
      for i in f:
        i = i.split()
        opcode = i[0]
        data = i[1:]
        i = instruction(opcode.lower(), [j.rstrip(',').lower() for j in data])
  return messages

def main():
  filenames = sys.argv[1:]
  messages = assemble(filenames)
  if messages:
    message_to_str = lambda message: (f"{message[0]}:{message[1]+1}: " if message.file_name else "") + ": ".join(message[2:])
    message_strs = [message_to_str(i) for i in messages]
    print("Assembler messages:")
    print('\n'.join(message_strs))

if __name__ == "__main__":
  main()
