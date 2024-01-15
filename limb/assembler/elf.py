class header:
  def __init__(self):
    self.e_ident = bytes([0x7f, 0x45, 0x4c, 0x46, 0x01, 0x01, 0x01] + [0x0 for i in range(9)])
    self.e_type = bytes((0x01, 0x00))
    self.e_machine = bytes((0x28, 0x00))
    self.e_version = bytes((0x01, 0x00, 0x00, 0x00))
    self.e_entry = None
    self.e_phoff = None
    self.e_shoff = None
    self.e_flags = bytes((0x00, 0x00, 0x00, 0x05))
    self.e_ehsize = bytes((0x00, 0x34))
    self.e_phentsize = None
    self.e_phnum = None
    self.e_shentsize = None
    self.e_shnum = None
    self.e_shstrndx = None

s_shstrtab = bytes("\0.symtab\0.strtab\0.shstrtab\0.text\0.data\0.bss\0.ARM.attributes\0", "ascii")

s_text = lambda x: bytes().join([int(i, 16).to_bytes(4, "little") for i in x])
