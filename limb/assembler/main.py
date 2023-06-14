#!/usr/bin/env python3

import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

instruction_conditions = {
  "eq": "0000",
  "ne": "0001",
  "cs": "0010",
  "cc": "0011",
  "mi": "0100",
  "pl": "0101",
  "vs": "0110",
  "vc": "0111",
  "hi": "1000",
  "ls": "1001",
  "ge": "1010",
  "lt": "1011",
  "gt": "1100",
  "le": "1101",
  "al": "1110"
}

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(instruction_conditions)})?"

imm_re = lambda group: f"(?P<{group}_imm>[^\s]*)"

reg_re = lambda group: f"r(?P<{group}_reg>{['|'.join([str(i) for i in range(14)])]})"

shift_re = lambda group: f"{reg_re(f'{group}_rm')}\s*,\s*{group}\s+(?:{reg_re(f'{group}_rs')}|{imm_re(f'{group}_b32')})"

oprnd2_res = (
  f"(?P<lsl>{shift_re('lsl')})",
  f"(?P<lsr>{shift_re('lsr')})",
  f"(?P<asr>{shift_re('asr')})",
  f"(?P<ror>{shift_re('ror')})",
  f"(?P<rrx>{reg_re('rrx')}\s+rrx)",
  f"(?P<reg>{reg_re('rm')})",
  f"(?P<imm>{imm_re('b32')})"
)

oprnd2_re = f"(?:{'|'.join(oprnd2_res)})"

def assemble(filenames):
  messages = []
  for filename in filenames:
    try:
      f = list(open(filename, 'r'))
    except FileNotFoundError:
      messages.append(assembler_message(None, None, "Error", f"can't open {filename}"))
      break
    else:
      for line, i in enumerate(f):
        opcode, data = i.split(maxsplit=1)
        i = instruction(opcode.lower(), data.rstrip().lower())
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
