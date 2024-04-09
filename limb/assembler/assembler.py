#!/usr/bin/env python3

import elf
import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

opcode_t = {
  "mov": "1101",
  "mvn": "1111",
  "add": "0100",
  "adc": "0101",
  "sub": "0010",
  "sbc": "0110",
  "rsb": "0011",
  "rsc": "0111",
  "cmp": "1010",
  "cmn": "1011",
  "tst": "1000",
  "teq": "1001",
  "and": "0000",
  "eor": "0001",
  "orr": "1100",
  "bic": "1110",
}

cond_t = {
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

def check_length(x, length):
  if (len(x) > length):
    return [assembler_message(None, None, "Error", f"invalid constant {(hex(int(x, 2)))} after fixup")]
  return []

enc_cond = lambda groups: cond_t[groups.opcode["cond"]] if "cond" in groups.opcode else cond_t["al"]

enc_reg = {str(i):f"{i:04b}" for i in range(14)}

def enc_a_mode2(groups):
  if "b12_imm" in groups.data:
    offset = f"{int(groups.data['b12_imm']):0>12b}"
    return check_length(offset, 12), offset
  elif "shift" in groups.data:
    messages, shift = enc_shift(groups)
    return messages, shift
  else:
    rm = enc_reg[groups.data["rm_reg"]]
    return [], "00000000" + rm

def enc_a_mode3(groups):
  if "b8_imm" in groups.data:
    imm = f"{int(groups.data['b8_imm']):0>8b}"
    return check_length(imm, 8), (imm[:4], imm[4:])
  else:
    rm = enc_reg[groups.data["rm_reg"]]
    return [], ("0000", rm)

def enc_shift(groups):
  messages = []
  ret = ""
  enc_shift_type = {
    "lsl": "00",
    "lsr": "01",
    "asr": "10",
    "ror": "11"
  }
  shift_type = enc_shift_type[groups.data["shift"]]
  if "b5_imm" in groups.data:
    ret = f"{int(groups.data['b5_imm']):0>5b}"
    messages = check_length(ret, 5)
    ret += shift_type + '0'
  else:
    ret = enc_reg[groups.data["rs_reg"]] + '0' + shift_type + '1'
  ret += enc_reg[groups.data["rm_reg"]]
  return messages, ret

enc_oprnd2 = {
  "shift": lambda x: enc_shift(x),
  "rrx": lambda x: ([], "00000110" + enc_reg[x.data["rm_reg"]]),
  "reg": lambda x: ([], "00000000" + enc_reg[x.data["rm_reg"]]),
  "imm": lambda x: (check_length(f"{int(x.data['b12_imm']):0>12b}", 12), f"{int(x.data['b12_imm']):0>12b}")
}

def enc_dpi(groups):
  cond = enc_cond(groups)
  oprnd2_type = list(groups.data)[-2]
  i = '0' if oprnd2_type == "reg" else '1'
  opcode = opcode_t[groups.opcode["opcode"]]
  s = '0' if 's' not in groups.opcode else '1'
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else "0000"
  rd = enc_reg[groups.data["rd_reg"]]
  messages, oprnd2 = enc_oprnd2[oprnd2_type](groups)
  return messages, cond + "00" + i + opcode + s + rn + rd + oprnd2

def enc_mi(groups):
  cond = enc_cond(groups)
  a = '0' if groups.opcode["opcode"][1] == "u" else '1'
  s = '0' if 's' not in groups.opcode else '1'
  rd = enc_reg[groups.data["rd_reg"]]
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else "0000"
  rs = enc_reg[groups.data["rs_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]
  return [], cond + "000000" + a + s + rd + rn + rs + "1001" + rm

def enc_mli(groups):
  cond = enc_cond(groups)
  u = '0' if 's' == groups.opcode["opcode"][0] else '1'
  a = '0' if groups.opcode["opcode"][2] == 'u' else '1'
  s = '0' if 's' not in groups.opcode else '1'
  rd_hi = enc_reg[groups.data["rd_hi_reg"]]
  rd_lo = enc_reg[groups.data["rd_lo_reg"]]
  rn = enc_reg[groups.data["rn_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]
  return [], cond + "00001" + u + a + s + rd_hi + rd_lo + rn + "1001" + rm

def enc_bei(groups):
  cond = enc_cond(groups)
  rn = enc_reg[groups.data["rn_reg"]]
  return [], cond + "000100101111111111110001" + rn

def enc_hdt(groups):
  cond = enc_cond(groups)
  p = '0' if "post" in groups.data else '1'
  u = '0' if "sign" in groups.data and groups.data["sign"] == '-' else '1'
  i = '0' if "b8_imm" not in groups.data else '1'
  w = '0' if p == '0' or 'pre' not in groups.data else '1'
  l = '0' if groups.opcode["opcode"][0] == 's' else '1'
  rn = enc_reg[groups.data["rn_reg"]]
  rd = enc_reg[groups.data["rd_reg"]]
  a_mode3 = enc_a_mode3(groups)
  s = '0' if 's' not in groups.opcode["opcode"][-2:] else '1'
  h = '0' if groups.opcode["opcode"][-1] != 'h' else '1'
  return [], cond + "000" + p + u + i + w + l + rn + rd + a_mode3[0] + '1' + s + h + '1' + a_mode3[1]

def enc_sdt(groups):
  cond = enc_cond(groups)
  p = '0' if "post" in groups.data else '1'
  u = '0' if "sign" in groups.data and groups.data["sign"] == '-' else '1'
  b = '0' if 'b' not in groups.opcode["opcode"][-2:] else '1'
  w = '0' if p == '0' or 'pre' not in groups.data else '1'
  l = '0' if groups.opcode["opcode"][0] == 's' else '1'
  rn = enc_reg[groups.data["rn_reg"]]
  rd = enc_reg[groups.data["rd_reg"]]
  messages, a_mode = enc_a_mode2(groups)
  return messages, cond + "011" + p + u + b + w + l + rn + rd + a_mode

def enc_bi(groups):
  cond = enc_cond(groups)
  l = '0' if groups.opcode["opcode"] == "b" else '1'
  offset = f"{int(groups.data['label_imm']):0>24b}"
  return [], cond + "101" + l + offset

def enc_nop(groups):
  cond = enc_cond(groups)
  return [], cond + "0011001000001111000000000000"

suffix_re = "(?P<s>s)?"

condition_re = f"(?P<cond>{'|'.join(cond_t)})?"

imm_re = lambda group: f"#(?P<{group}_imm>[\d]*)"

reg_re = lambda group: f"r(?P<{group}_reg>{'|'.join([str(i) for i in range(16)])})"

sign_re = f"(?P<sign>[+|-]\s*)?"

def shift_re(group, is_oprnd2):
  ret = '' if is_oprnd2 else sign_re
  ret += f"{reg_re('rm')}\s*"
  ret += '' if is_oprnd2 else ",\s*"
  ret += f"(?P<shift>{group})\s+"
  ret += f"(?:{reg_re(f'rs')}|{imm_re(f'b5')})" if is_oprnd2 else f"{imm_re('b5')}"
  return ret

oprnd2_re = (
  f"(?P<lsl>{shift_re('lsl', True)})",
  f"(?P<lsr>{shift_re('lsr', True)})",
  f"(?P<asr>{shift_re('asr', True)})",
  f"(?P<ror>{shift_re('ror', True)})",
  f"(?P<rrx>{reg_re('rm')}\s+rrx)",
  f"(?P<reg>{reg_re('rm')})",
  f"(?P<imm>{imm_re('b12')})")

a_mode2_re = (
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{imm_re('b12')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{shift_re('lsl', False)}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{shift_re('lsr', False)}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{shift_re('asr', False)}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{shift_re('ror', False)}\](?P<pre>!?)",
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx)\](?P<pre>!?)",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{imm_re('b12')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('lsl', False)})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('lsr', False)})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('asr', False)})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('ror', False)})",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx))")


a_mode3_re = (
  f"\[{reg_re('rn')}\s*,\s*{sign_re}{imm_re('b8')}\](?P<pre>!?)",
  f"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{imm_re('b8')})",
  a_mode2_re[1],
  a_mode2_re[8]
)

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

def opcode_re(opcode, has_cond, has_s):
  opcode = f"(?P<opcode>{'|'.join(opcode)})"
  cond = condition_re if has_cond else ''
  s = f"(?P<s>s)?" if has_s else ''
  return f"^{opcode}{cond}{s}$"

data_re = lambda res: fold(res)[0] if len(fold(res)) == 1 and not isinstance(fold(res)[0][0], list) else ['^' + "\s*,\s*".join(unfold(i)) + '$' for i in fold(res)]

instruction_t = (
  (instruction(opcode_re(("mov", "mvn"), True, True), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re(("add", "adc", "sub", "rsb", "rsc"), True, True), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re(("mul",), True, True), data_re([[reg_re("rd")], [reg_re("rm")], [reg_re("rs")]])), enc_mi),
  (instruction(opcode_re(("mla",), True, True), data_re([[reg_re("rd")], [reg_re("rm")], [reg_re("rs")], [reg_re("rn")]])), enc_mi),
  (instruction(opcode_re(("umull", "umlal", "smull", "smlal"), True, True), data_re([[reg_re("rd_lo")], [reg_re("rd_hi")], [reg_re("rm")], [reg_re("rn")]])), enc_mli),
  (instruction(opcode_re(("cmp", "cmn", "tst", "teq"), True, False), data_re([[reg_re("rd")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re(("and", "eor", "orr", "bic"), True, True), data_re([[reg_re("rd")], [reg_re("rn")], oprnd2_re])), enc_dpi),
  (instruction(opcode_re(("b", "bl"), True, False), data_re([[imm_re("label")]])), enc_bi),
  (instruction(opcode_re(("bx",), True, False), data_re([[reg_re("rn")]])), enc_bei),
  (instruction(opcode_re(("ldr", "ldrb", "str", "strb"), True, False), data_re([[reg_re("rd")], a_mode2_re])), enc_sdt),
  (instruction(opcode_re(("nop",), True, None), ["^$"]), enc_nop)
)

enc_instruction = [(instruction(re.compile(i.opcode), [re.compile(k) for k in i.data]), j) for i, j in instruction_t]

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
                i_messages, i_enc = fn(instruction(opcode_groups, data_groups))
                messages += [assembler_message(f, line, i.type, i.text) for i in i_messages]
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
  options = {
    "objfile": "a.out",
    "format": 't'
  }
  for i, j in enumerate(args):
    if j[0] == '-':
      if j[1] == 'o':
        if j[2:]:
          options["objfile"] = j[2:]
        else:
          options["objfile"] = args[i+1]
          del args[i+1]
      elif j[1:8] == "format=" and j[8:] in ('t', 'b'):
        options["format"] = j[8:]
      else:
        messages.append(assembler_message(None, None, "Error", f"unrecognized option: \"{j}\""))
    else:
      filenames.append(j)
  obj = "" if messages else assemble(messages, preprocess(messages, set(filenames)))
  if messages:
    message_to_str = lambda message: (f"{message[0]}:{message[1]+1}: " if message.file_name else "") + ": ".join(message[2:])
    message_strs = [message_to_str(i) for i in messages]
    print("Assembler messages:")
    print('\n'.join(message_strs))
    sys.exit(1)
  else:
    if options["format"] == 't':
      out = '\n'.join(obj)
      open(options["objfile"], "w").write(f"`define filename \".{options['objfile']}\"")
      options["objfile"] = f".{options['objfile']}"
    else:
      out = elf.to_bytes(elf.file(obj))
    open(options["objfile"], f"w{options['format']}").write(out)
    sys.exit(0)

if __name__ == "__main__":
  main()
