# Limb 
A 32-bit ARM assembler and scalar processor.

## Installation
Clone the repository.
```bash
git clone https://github.com/jeremykaragania/limb.git
```

## Usage
Assemble source code.
```bash
python3 assembler/main.py -o boot_rom infile
```
Compile test bench.
```bash
iverilog -I processor/ -o test_bench processor/test_bench.v
```
Execute test bench.
```bash
./test_bench
```

## License
[MIT](LICENSE)
