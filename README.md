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
python3 assembler/assembler.py -o memory infile
```
Compile test bench with processor memory.
```bash
iverilog -I processor/ -o test_bench memory processor/test_bench.v
```
Execute test bench.
```bash
./test_bench
```

## License
[MIT](LICENSE)
