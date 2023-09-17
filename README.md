![example workflow](https://github.com/npatsiatzis/1_wire/actions/workflows/regression.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/1_wire/actions/workflows/coverage.yml/badge.svg)

### 1_wire serial communication protocol RTL implementation

- includes the 1_wire master and a trivial 1_wire slave
- CoCoTB testbench for functional verification
    - $ make


### Repo Structure

This is a short tabular description of the contents of each folder in the repo.

| Folder | Description |
| ------ | ------ |
| [rtl](https://github.com/npatsiatzis/1_wire/tree/main/rtl/VHDL) | VHDL RTL implementation files |
| [cocotb_sim](https://github.com/npatsiatzis/1_wire/tree/main/cocotb_sim) | Functional Verification with CoCoTB (Python-based) |
| [pyuvm_sim](https://github.com/npatsiatzis/1_wire/tree/main/pyuvm_sim) | Functional Verification with pyUVM (Python impl. of UVM standard) |


This is the tree view of the strcture of the repo.
<pre>
<font size = "2">
.
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/1_wire/tree/main/rtl">rtl</a></b> </font>
│   └── VHD files
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/1_wire/tree/main/cocotb_sim">cocotb_sim</a></b></font>
│   ├── Makefile
│   └── python files
└── <font size = "4"><b><a 
 href="https://github.com/npatsiatzis/1_wire/tree/main/pyuvm_sim">pyuvm_sim</a></b></font>
    ├── Makefile
    └── python files
</pre>