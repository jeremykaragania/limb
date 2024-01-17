class file:
  def __init__(self, obj):
    self.header = header()
    self.sections = {
      '\0': bytes(),
      ".text": s_text(obj),
      ".data": s_data,
      ".bss": s_bss,
      ".shstrtab": s_shstrtab
    }
    self.section_header_table = {
      '\0': sh_undef,
      ".text": sh_text,
      ".data": sh_data,
      ".bss": sh_bss,
      ".shstrtab": sh_shstrtab
    }
    self.header.e_shoff = (int.from_bytes(self.header.e_ehsize, "little") + sum([len(i) for i in self.sections.values()])).to_bytes(4, "little")
    self.header.e_shnum = len(self.section_header_table).to_bytes(2, "little")
    self.header.e_shstrndx = (len(self.section_header_table) - 1).to_bytes(2, "little")
    x = len(bytes(self.header) + bytes().join([bytes(i) for i in self.sections.values()]))
    offset = 0
    for i, j in enumerate(self.sections):
      self.section_header_table[j].sh_offset = (len(bytes(self.header)) + offset).to_bytes(4, "little")
      self.section_header_table[j].sh_size = len(bytes(self.sections[j])).to_bytes(4, "little")
      offset += len(bytes(self.sections[j]))

  def __bytes__(self):
    return bytes(self.header) + bytes().join([bytes(i) for i in self.sections.values()]) + bytes().join([bytes(i) for i in self.section_header_table.values()])

class header:
  def __init__(self):
    self.e_ident = bytes([0x7f, 0x45, 0x4c, 0x46, 0x01, 0x01, 0x01] + [0x0 for i in range(9)])
    self.e_type = bytes((0x01, 0x00))
    self.e_machine = bytes((0x28, 0x00))
    self.e_version = bytes((0x01, 0x00, 0x00, 0x00))
    self.e_entry = bytes((0x00, 0x00, 0x00, 0x00))
    self.e_phoff = bytes((0x00, 0x00, 0x00, 0x00))
    self.e_shoff = None
    self.e_flags = bytes((0x00, 0x00, 0x00, 0x05))
    self.e_ehsize = bytes((0x34, 0x00))
    self.e_phentsize = bytes((0x00, 0x00))
    self.e_phnum = bytes((0x00, 0x00))
    self.e_shentsize = bytes((0x28, 0x00))
    self.e_shnum = None
    self.e_shstrndx = None

  def __bytes__(self):
    return to_bytes(self)

s_shstrtab = bytes("\0.text\0.data\0.bss\0.symtab\0.strtab\0.shstrtab\0", "ascii")

s_text = lambda x: bytes().join([int(i, 16).to_bytes(4, "little") for i in x])

s_data = bytes()

s_bss = bytes()

class section_header:
  def __init__(self, sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size, sh_link, sh_info, sh_addralign, sh_entsize):
    self.sh_name = sh_name
    self.sh_type = sh_type
    self.sh_flags = sh_flags
    self.sh_addr = sh_addr
    self.sh_offset = sh_offset
    self.sh_size = sh_size
    self.sh_link = sh_link
    self.sh_info = sh_info
    self.sh_addralign = sh_addralign
    self.sh_entsize = sh_entsize

  def __bytes__(self):
    return to_bytes(self)

sh_undef = section_header(
  sh_name=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_type=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_flags=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addr=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_offset=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_size=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_link=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_info=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addralign=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_entsize=bytes((0x00, 0x00, 0x00, 0x00)))

sh_text = section_header(
  sh_name=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_type=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_flags=bytes((0x06, 0x00, 0x00, 0x00)),
  sh_addr= bytes((0x00, 0x00, 0x00, 0x00)),
  sh_offset=None,
  sh_size=None,
  sh_link=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_info=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addralign=bytes((0x04, 0x00, 0x00, 0x00)),
  sh_entsize=bytes((0x00, 0x00, 0x00, 0x00)))

sh_data = section_header(
  sh_name=bytes((0x07, 0x00, 0x00, 0x00)),
  sh_type=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_flags=bytes((0x03, 0x00, 0x00, 0x00)),
  sh_addr=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_offset=None,
  sh_size=None,
  sh_link=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_info=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addralign=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_entsize=bytes((0x00, 0x00, 0x00, 0x00)))

sh_bss = section_header(
  sh_name=bytes((0x0d, 0x00, 0x00, 0x00)),
  sh_type=bytes((0x08, 0x00, 0x00, 0x00)),
  sh_flags=bytes((0x03, 0x00, 0x00, 0x00)),
  sh_addr=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_offset=None,
  sh_size=None,
  sh_link=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_info=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addralign=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_entsize=bytes((0x00, 0x00, 0x00, 0x00)))

sh_shstrtab = section_header(
  sh_name=bytes((0x22, 0x00, 0x00, 0x00)),
  sh_type=bytes((0x03, 0x00, 0x00, 0x00)),
  sh_flags=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addr= bytes((0x00, 0x00, 0x00, 0x00)),
  sh_offset=None,
  sh_size=None,
  sh_link=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_info=bytes((0x00, 0x00, 0x00, 0x00)),
  sh_addralign=bytes((0x01, 0x00, 0x00, 0x00)),
  sh_entsize=bytes((0x00, 0x00, 0x00, 0x00)))

to_bytes = lambda x: bytes().join(vars(x).values())
