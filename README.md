# RISCV-CPU
## 设计目标
实现一个简单的RISC-CPU，支持`RV32IC`指令集的37个核心指令和简单的特权模式/用户模式切换。

依据的RISC-V标准为`20240411`版的（<https://github.com/riscv/riscv-isa-manual/releases/tag/20240411>）。

## CPU部分架构简图
[说明文档](docs/design.md)
![pic](docs/design.png)

## 项目结构
```
📦RISCV-CPU
┣ 📂fpga            // FPGA 开发板控制程序
┣ 📂script          // 相关脚本
┣ 📂sim             // 仿真运行 Testbench
┣ 📂docs            // 相关文档、设计
┣ 📂src             // HDL 源代码
┃ ┣ 📂common       // 题面提供部件源代码
┃ ┣ 📂components   // CPU各组件代码
┃ ┣ 📜cpu.v        // CPU 核心代码
┃ ┗ 📜riscv_top.v  // 整个机器的顶层模块
┣ 📜Makefile        // 编译及测试脚本
┗ 📜README.md       // 项目README
```