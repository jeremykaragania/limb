# Limb
An ARMv7-A scalar processor.

## Installation
Clone the repository.
```bash
git clone https://github.com/jeremykaragania/limb.git
```

## Usage
Assemble source code to processor memory.
```bash
python3 tools/assembler.py -o memory examples/arithmetic.s
```
Compile test bench with processor memory.
```bash
iverilog -I limb/ -o test_bench memory limb/test_bench.v
```
Execute test bench.
```bash
./test_bench
```

## License
[MIT](LICENSE)
