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
  "mla": "0001",
  "umull": "0100",
  "umlal": "0101",
  "smull": "0110",
  "smlal": "0111",
  "cmn": "1011",
  "tst": "1000",
  "teq": "1001",
  "and": "0000",
  "eor": "0001",
  "orr": "1100",
  "bic": "1110",
}

enc_cond = {
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

def enc_a_mode(groups):
  if "b12_imm" in groups.data:
    offset = f"{int(groups.data['b12_imm']):0>12b}"
    return offset
  elif "shift" in groups.data:
    shift = enc_shift(groups)
    return shift
  else:
    rm = enc_reg[groups.data["rm_reg"]]
    return "00000000" + rm

def enc_shift(groups):
  ret = ""
  enc_shift_type = {
    "lsl": "00",
    "lsr": "01",
    "asr": "10",
    "ror": "11"
  }
  shift_type = enc_shift_type[groups.data["shift"]]
  if "b5_imm" in groups.data:
    ret = f"{int(groups.data['b5_imm']):0>5b}" + shift_type + '0'
  else:
    ret = enc_reg[groups.data["rs_reg"]] + '0' + shift_type + '1'
  ret += enc_reg[groups.data["rm_reg"]]
  return ret

enc_oprnd2 = {
  "lsl": lambda x: enc_shift(x),
  "lsr": lambda x: enc_shift(x),
  "asr": lambda x: enc_shift(x),
  "ror": lambda x: enc_shift(x),
  "rrx": lambda x: "00000110" + enc_reg[x.data["rm_reg"]],
  "reg": lambda x: enc_reg[x.data["rm_reg"]],
  "imm": lambda x: f"{int(x.data['b12_imm']):0>12b}"
}

def enc_dpi(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  oprnd2_type = list(groups.data)[1]
  i = '0' if oprnd2_type == "reg" else '1'
  opcode = enc_opcode[groups.opcode["opcode"]]
  s = '0' if 's' not in groups.opcode else '1'
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else "0000"
  rd = enc_reg[groups.data["rd_reg"]]
  oprnd2 = enc_oprnd2[oprnd2_type](groups)
  return cond + "00" + i + opcode + s + rn + rd + oprnd2

def enc_mi(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  a = '0' if groups.opcode["opcode"][2] == "u" else '1'
  s = '0' if 's' not in groups.opcode else '1'
  rd = enc_reg[groups.data["rd_reg"]]
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else "0000"
  rs = enc_reg[groups.data["rs_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]
  return cond + "000000" + a + s + rd + rn + rs + "1001" + rm

def enc_mli(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  u = '0' if 's' == groups.opcode["opcode"][0] else '1'
  a = '0' if groups.opcode["opcode"][2] == 'u' else '1'
  s = '0' if 's' not in groups.opcode else '1'
  rd_hi = enc_reg[groups.data["rd_hi_reg"]]
  rd_lo = enc_reg[groups.data["rd_lo_reg"]]
  rn = enc_reg[groups.data["rn_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]
  return cond + "00001" + u + a + s + rd_hi + rd_lo + rn + "1001" + rm

def enc_bei(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  rn = enc_reg[groups.data["rn_reg"]]
  return cond + "000100101111111111110001" + rn

def enc_bi(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  l = '0' if groups.opcode["opcode"] == "b" else '1'
  offset = f"{int(groups.data['label_imm']):0>24b}"
  return cond + "101" + l + offset

def enc_sdt(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  p = '0' if 'post' in groups.data else '1'
  u = '0' if "sign" in groups.data and groups.data["sign"] == '-' else '1'
  b = '0'
  w = '0' if p == '0' or 'pre' not in groups.data else '1'
  l = '0'
  rn = enc_reg[groups.data["rn_reg"]]
  rd = enc_reg[groups.data["rd_reg"]]
  a_mode = enc_a_mode(groups)
  return cond + "011" + p + u + b + w + l + rn + rd + a_mode

def enc_nop(groups):
  cond = enc_cond[groups.opcode["cond"]] if "cond" in groups.opcode else enc_cond["al"]
  return cond + "0011001000001111000000000000"

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(enc_cond)})?"

imm_re = lambda group: f"(?P<{group}_imm>[\d]*)"

reg_re = lambda group: f"r(?P<{group}_reg>{'|'.join([str(i) for i in range(16)])})"

shift_re = lambda group: f"{reg_re('rm')}\s*(?P<shift>{group})\s+(?:{reg_re(f'rs')}|{imm_re(f'b5')})"

oprnd2_re = (
  f"(?P<lsl>{shift_re('lsl')})",
  f"(?P<lsr>{shift_re('lsr')})",
  f"(?P<asr>{shift_re('asr')})",
  f"(?P<ror>{shift_re('ror')})",
  f"(?P<rrx>{reg_re('rrx')}\s*,\s*rrx)",
  f"(?P<reg>{reg_re('rm')})",
  f"(?P<imm>{imm_re('b12')})")

sign_re = f"(?P<sign>[+|-]\s*)?"

a_mode2_re = (
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{imm_re('b12')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>lsl)\s+{imm_re('b5')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>lsr)\s+{imm_re('b5')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>asr)\s+{imm_re('b5')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>ror)\s+{imm_re('b5')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx)\](?P<pre>!?)",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{imm_re('b12')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>lsl)\s+{imm_re('b5')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>lsr)\s+{imm_re('b5')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>asr)\s+{imm_re('b5')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>ror)\s+{imm_re('b5')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx))")

def fold(x):
  if len(x) == 1:
    return x
  while True:
    fst, snd, other = x[0], x[1], x[2:]
    ret = []
    for j in fst:
      for k in snd:
        ret += [[j, k]]
    if other:
      x = [ret] + other
    else:
      return ret

def unfold(x):
  ret = []
  while True:
    fst, snd = x[0], x[-1]
    ret = [snd] + ret
    x = fst
    if not isinstance(x, list):
      ret = [x] + ret
      return ret

opcode_re = lambda opcode, optional: f"^(?P<opcode>{opcode}){suffix_re if 's' in optional else ''}{condition_re if 'cond' in optional else ''}$"

data_re = lambda res: fold(res)[0] if len(fold(res)) == 1 and not isinstance(fold(res)[0][0], list) else ['^' + "\s*,\s*".join(unfold(i)) + '$' for i in fold(res)]

enc_instruction_re = (
  (instruction(opcode_re("mov", ('s', "cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("mvn", ('s', "cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("add", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("adc", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("sub", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("rsb", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("rsc", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("mul", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rm")], [reg_re("rs")]])), enc_mi),
  (instruction(opcode_re("mla", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rm")], [reg_re("rs")], [reg_re("rn")]])), enc_mi),
  (instruction(opcode_re("umull", ('s', "cond")), data_re([[reg_re("rd_lo")], [reg_re("rd_hi")], [reg_re("rm")], [reg_re("rn")]])), enc_mli),
  (instruction(opcode_re("umlal", ('s', "cond")), data_re([[reg_re("rd_lo")], [reg_re("rd_hi")], [reg_re("rm")], [reg_re("rn")]])), enc_mli),
  (instruction(opcode_re("smull", ('s', "cond")), data_re([[reg_re("rd_lo")], [reg_re("rd_hi")], [reg_re("rm")], [reg_re("rn")]])), enc_mli),
  (instruction(opcode_re("smlal", ('s', "cond")), data_re([[reg_re("rd_lo")], [reg_re("rd_hi")], [reg_re("rm")], [reg_re("rn")]])), enc_mli),
  (instruction(opcode_re("cmp", ("cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("cmn", ("cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("tst", ("cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("teq", ("cond")), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("and", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("eor", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("orr", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("bic", ('s', "cond")), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re("b", ("cond")), data_re([[imm_re("label")]])), enc_bi),
  (instruction(opcode_re("bl", ("cond")), data_re([[imm_re("label")]])), enc_bi),
  (instruction(opcode_re("bx", ("cond")), data_re([[reg_re("rn")]])), enc_bei),
  (instruction(opcode_re("nop", ("cond")), ["^$"]), enc_nop),
)

enc_instruction = [(instruction(re.compile(i.opcode), [re.compile(k) for k in i.data]), j) for i, j in enc_instruction_re]

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
      opcode_match = 0
      for i_re, fn in enc_instruction:
        opcode_match = i_re.opcode.match(i.opcode)
        if opcode_match:
          data_match = 0
          for j in i_re.data:
            data_match = j.match(i.data)
            if data_match:
              if not messages:
                data_groups = {j:k for j, k in data_match.groupdict().items() if k}
                opcode_groups = {j:k for j, k in opcode_match.groupdict().items() if k}
                i_enc = fn(instruction(opcode_groups, data_groups))
                obj.append((f"{int(i_enc, 2):<04x}"))
                break
          if not data_match:
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
    if j[0] == '-':
      if j[1] == 'o':
        if j[2:]:
          objfile = j[2:]
        else:
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
