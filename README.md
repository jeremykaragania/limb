# Limb
An ARMv7-A scalar processor.

## Installation
```bash
git clone https://github.com/jeremykaragania/limb.git
cd limb
iverilog -I limb/ -o test_bench limb/test_bench.v
```

## Usage
```bash
python3 tools/assembler.py -o memory examples/arithmetic.s
./test_bench
```

## License
[MIT](LICENSE)
