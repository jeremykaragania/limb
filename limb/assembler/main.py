#!/usr/bin/env python3

import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

enc_opcode = {
  "mov": "1101",
  "mvn": "1111",
  "add": "0100",
  "adc": "0101",
  "sub": "0010",
  "sbc": "0110",
  "rsb": "0011",
  "rsc": "0111",
  "cmp": "1010",
  "mul": "0000",
  "umull": "0100",
  "umlal": "0101",
  "smull": "0110",
  "smlal": "0111",
  "mla": "0001",
  "cmn": "1011",
  "tst": "1000",
  "teq": "1001",
  "and": "0000",
  "eor": "0001",
  "orr": "1100",
  "bic": "1110"
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
  "imm": lambda x: f"{int(x['b32_imm']):b}"
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
  oprnd2 = f"{enc_oprnd2[oprnd2_type](groups.data):0>12}"
  oprnd2_type = "0" if oprnd2_type == "reg" else "1"
  return cond + "00" + oprnd2_type + opcode + s + regs["rn_reg"] + regs["rd_reg"] + oprnd2

def enc_mul(groups):
  cond = enc_condition[groups.opcode["cond"]] if "cond" in groups.opcode else enc_condition["al"]
  opcode = enc_opcode[groups.opcode["opcode"]]
  s = '1' if 's' in groups.opcode else '0'
  regs = {
    "rn_reg": "0000",
    "rd_reg": "0000",
    "rs_reg": "0000",
    "rm_reg": "0000"
  }
  for i in regs:
    if i in groups.data:
      regs[i] = enc_reg[groups.data[i]]
      del groups.data[i]
  return cond + "000" + opcode + s + regs["rd_reg"] + regs["rn_reg"] + regs["rs_reg"] + "1001" + regs["rm_reg"]

def enc_mul_long(groups):
  cond = enc_condition[groups.opcode["cond"]] if "cond" in groups.opcode else enc_condition["al"]
  opcode = enc_opcode[groups.opcode["opcode"]]
  s = '1' if 's' in groups.opcode else '0'
  regs = {
    "rn_reg": "0000",
    "rd_hi_reg": "0000",
    "rd_lo_reg": "0000",
    "rm_reg": "0000",
    "rm_reg": "0000"
  }
  for i in regs:
    if i in groups.data:
      regs[i] = enc_reg[groups.data[i]]
      del groups.data[i]
  return cond + "000" + opcode + s + regs["rd_hi_reg"] + regs["rd_lo_reg"] + regs["rn_reg"] + "1001" + regs["rm_reg"]

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(enc_condition)})?"

imm_re = lambda group: f"(?P<{group}_imm>[^\s]*)"

reg_re = lambda group: f"r(?P<{group}_reg>{'|'.join([str(i) for i in range(14)])})"

shift_re = lambda group: f"{reg_re(f'{group}_rm')}\s*,\s*{group}\s+(?:{reg_re(f'{group}_rs')}|{imm_re(f'{group}_b5')})"

oprnd2_re = '|'.join((
  f"(?P<lsl>{shift_re('lsl')})",
  f"(?P<lsr>{shift_re('lsr')})",
  f"(?P<asr>{shift_re('asr')})",
  f"(?P<ror>{shift_re('ror')})",
  f"(?P<rrx>{reg_re('rrx')}\s*,\s*rrx)",
  f"(?P<reg>{reg_re('rm')})",
  f"(?P<imm>{imm_re('b32')})"))

opcode_re = lambda opcode, optional: f"^(?P<opcode>{opcode}){suffix_re if 's' in optional else ''}{condition_re if 'cond' in optional else ''}$"

data_re = lambda res: "^" + '\s*,\s*'.join(res) + "$"

enc_instruction = {
  instruction(re.compile(opcode_re("mov", ("s", "cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("mvn", ("s", "cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("add", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("adc", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("sub", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("rsb", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("rsc", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("mul", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rm"), reg_re("rs"))))): enc_mul,
  instruction(re.compile(opcode_re("mla", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rm"), reg_re("rs"), reg_re("rn"))))): enc_mul,
  instruction(re.compile(opcode_re("umull", ("s", "cond"))), re.compile(data_re((reg_re("rd_lo"), reg_re("rd_hi"), reg_re("rm"), reg_re("rs"))))): enc_mul_long,
  instruction(re.compile(opcode_re("umlal", ("s", "cond"))), re.compile(data_re((reg_re("rd_lo"), reg_re("rd_hi"), reg_re("rm"), reg_re("rs"))))): enc_mul_long,
  instruction(re.compile(opcode_re("smull", ("s", "cond"))), re.compile(data_re((reg_re("rd_lo"), reg_re("rd_hi"), reg_re("rm"), reg_re("rs"))))): enc_mul_long,
  instruction(re.compile(opcode_re("smlal", ("s", "cond"))), re.compile(data_re((reg_re("rd_lo"), reg_re("rd_hi"), reg_re("rm"), reg_re("rs"))))): enc_mul_long,
  instruction(re.compile(opcode_re("cmp", ("cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("cmn", ("cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("tst", ("cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("teq", ("cond"))), re.compile(data_re((reg_re("rd"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("and", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("eor", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("orr", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
  instruction(re.compile(opcode_re("bic", ("s", "cond"))), re.compile(data_re((reg_re("rd"), reg_re("rn"), f"(?:{oprnd2_re})")))): enc_proc,
}

def preprocess(messages, filenames):
  files = {}
  for filename in filenames:
    try:
      f = open(filename, 'r').read()
    except:
      messages.append(assembler_message(None, None, "Error", f"can't open {filename}"))
      return []
    else:
      f = re.sub("\/\*(?:.|\n)*\*\/", '', f)
      f = f.split('\n')
      files[filename] = []
      for line, i in enumerate(f):
        if not i or i.isspace():
          continue
        opcode = ""
        data = ""
        try:
          opcode, data = i.split(maxsplit=1)
        except ValueError:
          opcode = i
        files[filename].append(instruction(opcode.lower(), data.rstrip().lower()))
  return files

def assemble(messages, files):
  obj = []
  for f in files:
    for line, i in enumerate(files[f]):
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
              obj.append((f"{int(i_enc, 2):<04x}"))
          else:
            messages.append(assembler_message(f, line, "Error", f"no such data for \"{i.opcode}\": \"{i.data}\""))
          break
      if not opcode_match:
        messages.append(assembler_message(f, line, "Error", f"no such instruction opcode: \"{i.opcode}\""))
  return obj

def main():
  args = sys.argv[1:]
  filenames = []
  messages = []
  objfile = "a.out"
  for i, j in enumerate(args):
    if j == "-o":
      objfile = args[i+1]
      del args[i+1]
    else:
      filenames.append(j)
  obj = assemble(messages, preprocess(messages, set(filenames)))
  if messages:
    message_to_str = lambda message: (f"{message[0]}:{message[1]+1}: " if message.file_name else "") + ": ".join(message[2:])
    message_strs = [message_to_str(i) for i in messages]
    print("Assembler messages:")
    print('\n'.join(message_strs))
  else:
    open(objfile, "w").write('\n'.join(obj))

if __name__ == "__main__":
  main()
