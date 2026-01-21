#!/usr/bin/env python3

import re
import sys
from collections import namedtuple

instruction = namedtuple("instruction", ["opcode", "data"])

assembler_message = namedtuple("assembler_message", ["file_name", "line_number", "type", "text"])

opcode_t = {
  "and": 0b0000,
  "eor": 0b0001,
  "sub": 0b0010,
  "rsb": 0b0011,
  "add": 0b0100,
  "adc": 0b0101,
  "sbc": 0b0110,
  "rsc": 0b0111,
  "tst": 0b1000,
  "teq": 0b1001,
  "cmp": 0b1010,
  "cmn": 0b1011,
  "orr": 0b1100,
  "mov": 0b1101,
  "lsl": 0b1101,
  "asr": 0b1101,
  "rrx": 0b1101,
  "ror": 0b1101,
  "bic": 0b1110,
  "mvn": 0b1111
}

cond_t = {
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

def check_size(x, size):
  if (x > size):
    return [assembler_message(None, None, "Error", f"invalid constant {(hex(x))} after fixup")]

  return []

enc_cond = lambda groups: cond_t[groups.opcode["cond"]] if "cond" in groups.opcode else cond_t["al"]

enc_reg = {str(i):i for i in range(14)}

def enc_a_mode2(groups):
  if "b12_imm" in groups.data:
    offset = int(groups.data['b12_imm'])
    return check_size(offset, 4095), offset
  elif "shift" in groups.data:
    messages, shift = enc_shift(groups)
    return messages, shift
  else:
    rm = enc_reg[groups.data["rm_reg"]]
    return [], rm

def enc_a_mode3(groups):
  if "b8_imm" in groups.data:
    imm = f"{int(groups.data['b8_imm']):0>8b}"
    return check_size(imm, 8), (imm[:4], imm[4:])
  else:
    rm = enc_reg[groups.data["rm_reg"]]
    return [], ("0000", rm)

def enc_shift(groups):
  messages = []
  ret = 0
  enc_shift_type = {
    "lsl": 0b00,
    "lsr": 0b01,
    "asr": 0b10,
    "ror": 0b11
  }
  shift_type = enc_shift_type[groups.data["shift"]]

  if "b5_imm" in groups.data:
    imm = int(groups.data['b5_imm'])
    messages = check_size(imm, 31)
    ret |= imm << 7 | shift_type << 5
  else:
    ret |= enc_reg[groups.data["rs_reg"]] << 8 | shift_type << 5 | 1 << 4

  ret |= enc_reg[groups.data["rm_reg"]]

  return messages, ret

enc_oprnd2 = {
  "shift": lambda x: enc_shift(x),
  "rrx": lambda x: ([], enc_reg[x.data["rm_reg"]]),
  "reg": lambda x: ([], enc_reg[x.data["rm_reg"]]),
  "imm": lambda x: (check_size(int(x.data['b12_imm']), 4095), int(x.data['b12_imm']))
}

def enc_dpi(groups):
  cond = enc_cond(groups)
  oprnd2_type = list(groups.data)[-2]
  i = 0 if oprnd2_type == "reg" else 1
  opcode = opcode_t[groups.opcode["opcode"]]
  s = 0 if 's' not in groups.opcode else 1
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else 0b0000
  rd = enc_reg[groups.data["rd_reg"]]
  messages, oprnd2 = enc_oprnd2[oprnd2_type](groups)

  return messages, cond << 28 | i << 25 | opcode << 21 | s << 20 | rn << 16 | rd << 12 | oprnd2

def enc_mi(groups):
  cond = enc_cond(groups)
  a = 0 if groups.opcode["opcode"][1] == "u" else 1
  s = 0 if "s" not in groups.opcode else 1
  rd = enc_reg[groups.data["rd_reg"]]
  rn = enc_reg[groups.data["rn_reg"]] if "rn_reg" in groups.data else 0b0000
  rs = enc_reg[groups.data["rs_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]

  return [], cond << 28 | a << 21 | s << 20 | rd << 16 | rn << 12 | rs << 8 | 0b1001 << 4 | rm

def enc_mli(groups):
  cond = enc_cond(groups)
  u = 0 if 's' == groups.opcode["opcode"][0] else 1
  a = 0 if groups.opcode["opcode"][2] == 'u' else 1
  s = 0 if 's' not in groups.opcode else 1
  rd_hi = enc_reg[groups.data["rd_hi_reg"]]
  rd_lo = enc_reg[groups.data["rd_lo_reg"]]
  rn = enc_reg[groups.data["rn_reg"]]
  rm = enc_reg[groups.data["rm_reg"]]

  return [], cond << 28 | 1 << 23 | u << 22 | a << 21 | s << 20 | rd_hi << 16 | rd_lo << 12 | rn << 8 | 0b1001 << 4 | rm

def enc_bei(groups):
  cond = enc_cond(groups)
  rn = enc_reg[groups.data["rn_reg"]]

  return [], cond << 28 | 0b000100101111111111110001 << 4 | rn

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
  p = 0 if "post" in groups.data else 1
  u = 0 if "sign" in groups.data and groups.data["sign"] == '-' else 1
  b = 0 if 'b' not in groups.opcode["opcode"][-2:] else 1
  w = 0 if p == 0 or 'pre' not in groups.data else 1
  l = 0 if groups.opcode["opcode"][0] == 's' else 1
  rn = enc_reg[groups.data["rn_reg"]]
  rd = enc_reg[groups.data["rd_reg"]]
  messages, a_mode = enc_a_mode2(groups)

  return messages, cond << 28 | 0b011 << 25 | p << 24 | u << 23 | b << 22 | w << 21 | l << 20 | rn << 16 | rd << 12 | a_mode

def enc_bi(groups):
  cond = enc_cond(groups)
  l = 0 if groups.opcode["opcode"] == "b" else 1
  offset = int(groups.data['label_imm'])

  return [], cond << 28 | 0b101 << 25 | l << 24 | offset

def enc_nop(groups):
  cond = enc_cond(groups)
  return [], cond << 28 | 0b0011001000001111000000000000

suffix_re = "(?P<s>s)?"

condition_re = fr"(?P<cond>{'|'.join(cond_t)})?"

imm_re = lambda group: fr"#(?P<{group}_imm>[\d]*)"

reg_re = lambda group: fr"r(?P<{group}_reg>{'|'.join([str(i) for i in range(16)])})"

sign_re = fr"(?P<sign>[+|-]\s*)?"

def shift_re(group, is_oprnd2):
  ret = '' if is_oprnd2 else sign_re
  ret += fr"{reg_re('rm')}\s*"
  ret += r'' if is_oprnd2 else r",\s*"
  ret += fr"(?P<shift>{group})\s+"
  ret += fr"(?:{reg_re(f'rs')}|{imm_re(f'b5')})" if is_oprnd2 else fr"{imm_re('b5')}"

  return ret

oprnd2_re = (
  fr"(?P<lsl>{shift_re('lsl', True)})",
  fr"(?P<lsr>{shift_re('lsr', True)})",
  fr"(?P<asr>{shift_re('asr', True)})",
  fr"(?P<ror>{shift_re('ror', True)})",
  fr"(?P<rrx>{reg_re('rm')}\s+rrx)",
  fr"(?P<reg>{reg_re('rm')})",
  fr"(?P<imm>{imm_re('b12')})")

a_mode2_re = (
  fr"\[{reg_re('rn')}\s*,\s*{sign_re}{imm_re('b12')}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{shift_re('lsl', False)}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{shift_re('lsr', False)}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{shift_re('asr', False)}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{shift_re('ror', False)}\](?P<pre>!?)",
  fr"\[{reg_re('rn')}\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx)\](?P<pre>!?)",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{imm_re('b12')})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('lsl', False)})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('lsr', False)})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('asr', False)})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{shift_re('ror', False)})",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{reg_re('rm')}\s*,\s*(?P<shift>rrx))")


a_mode3_re = (
  fr"\[{reg_re('rn')}\s*,\s*{sign_re}{imm_re('b8')}\](?P<pre>!?)",
  fr"(?P<post>\[{reg_re('rn')}\]\s*,\s*{sign_re}{imm_re('b8')})",
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
  opcode = fr"(?P<opcode>{'|'.join(opcode)})"
  cond = condition_re if has_cond else ''
  s = fr"(?P<s>s)?" if has_s else ''

  return fr"^{opcode}{cond}{s}$"

def data_re(res):
    f = fold(res)

    if len(f == 1 and not isinstance(f[0][0], list):
        return f[0]

    return [r'^' + r"\s*,\s*".join(unfold(i)) + r'$' for i in fold(res)]

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
      f = re.sub(r"\/\*(?:.|\n)*\*\/", '', f)
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
                obj.append(i_enc.to_bytes(4, "little"))
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
    obj_out = b"".join(obj)
    mem_out = "\n".join([f"{b:>02x}" for b in obj_out])
    open(objfile, 'wb').write(obj_out)
    open(".memory", 'w').write(mem_out)
    sys.exit(0)

if __name__ == "__main__":
  main()
