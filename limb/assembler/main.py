#!/usr/bin/env python3

import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

enc_opcode = {
  "mov": "1101",
}

enc_condition = {
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

enc_reg = {str(i):f"{i:04b}" for i in range(14)}

def enc_shift(x, y):
  key = list(x)[0]
  ret = ""
  if f"{key}_b5_imm" in x:
    ret = f"{int(x[key+'_b5_imm']):05b}" + y[1:]
  else:
    ret = enc_reg[x[f"{key}_rs_reg"]] + y
  ret += enc_reg[x[f"{key}_rm_reg"]]
  return ret

enc_oprnd2 = {
  "lsl": lambda x: enc_shift(x, "0001"),
  "lsr": lambda x: enc_shift(x, "0011"),
  "asr": lambda x: enc_shift(x, "0101"),
  "ror": lambda x: enc_shift(x, "0111"),
  "rrx": lambda x: "00000110" + enc_reg[x[f"{list(x)[0]}_reg"]],
  "reg": lambda x: enc_reg[x["rm_reg"]],
  "imm": lambda x: f"{int(x['b32_imm']):012b}"
}

def enc_proc(groups):
  cond = enc_condition[groups.opcode["cond"]] if "cond" in groups.opcode else enc_condition["al"]
  opcode = enc_opcode[groups.opcode["opcode"]]
  s = '1' if 's' in groups.opcode else '0'
  regs = {
    "rn_reg": "0000",
    "rd_reg": "0000"
  }
  for i in regs:
    if i in groups.data:
      regs[i] = enc_reg[groups.data[i]]
      del groups.data[i]
  oprnd2_type = list(groups.data)[0]
  oprnd2 = enc_oprnd2[oprnd2_type](groups.data)
  return cond + "001" + opcode + s + regs["rn_reg"] + regs["rd_reg"] + oprnd2

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(enc_condition)})?"

imm_re = lambda group: f"(?P<{group}_imm>[^\s]*)"

reg_re = lambda group: f"r(?P<{group}_reg>{['|'.join([str(i) for i in range(14)])]})"

shift_re = lambda group: f"{reg_re(f'{group}_rm')}\s*,\s*{group}\s+(?:{reg_re(f'{group}_rs')}|{imm_re(f'{group}_b5')})"

oprnd2_re = (
  f"(?P<lsl>{shift_re('lsl')})",
  f"(?P<lsr>{shift_re('lsr')})",
  f"(?P<asr>{shift_re('asr')})",
  f"(?P<ror>{shift_re('ror')})",
  f"(?P<rrx>{reg_re('rrx')}\s*,\s*rrx)",
  f"(?P<reg>{reg_re('rm')})",
  f"(?P<imm>{imm_re('b32')})"
)

enc_instruction = {
  instruction(re.compile(f"^(?P<opcode>mov){suffix_re}{condition_re}$"), re.compile(f"^{reg_re('rd')}\s*,\s*(?:{'|'.join(oprnd2_re)})$")): enc_proc
}

def assemble(filenames, objfile="a.out"):
  messages = []
  for filename in filenames:
    try:
      f = list(open(filename, 'r'))
    except:
      messages.append(assembler_message(None, None, "Error", f"can't open {filename}"))
      break
    else:
      obj = bytearray()
      for line, i in enumerate(f):
        opcode = ""
        data = ""
        try:
          opcode, data = i.split(maxsplit=1)
        except ValueError:
          opcode = i
        i = instruction(opcode.lower(), data.rstrip().lower())
        opcode_match = None
        for i_re in enc_instruction:
          opcode_match = i_re.opcode.match(i.opcode)
          if opcode_match:
            data_match = i_re.data.match(i.data)
            if data_match:
              if not messages:
                opcode_groups = {j:k for j, k in opcode_match.groupdict().items() if k}
                data_groups = {j:k for j, k in data_match.groupdict().items() if k}
                i_enc = enc_instruction[i_re](instruction(opcode_groups, data_groups))
                obj.extend(bytes().fromhex(hex(int(i_enc, 2))[2:])[::-1])
            else:
              messages.append(assembler_message(filename, line, "Error", f"no such instruction data: \"{data.rstrip()}\""))
            break
        if not opcode_match:
          messages.append(assembler_message(filename, line, "Error", f"no such instruction opcode: \"{opcode}\""))
      if not messages:
        open(objfile, "wb").write(obj)
  return messages

def main():
  args = sys.argv[1:]
  filenames = []
  objfile = "a.out"
  for i, j in enumerate(args):
    if j == "-o":
      objfile = args[i+1]
      del args[i+1]
    else:
      filenames.append(j)
  messages = assemble(set(filenames), objfile)
  if messages:
    message_to_str = lambda message: (f"{message[0]}:{message[1]+1}: " if message.file_name else "") + ": ".join(message[2:])
    message_strs = [message_to_str(i) for i in messages]
    print("Assembler messages:")
    print('\n'.join(message_strs))

if __name__ == "__main__":
  main()
