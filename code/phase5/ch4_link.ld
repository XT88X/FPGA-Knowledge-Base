/* =============================================================================
 * ch4_link.ld — ch4 SoC 裸机链接脚本
 *   RAM 起点 0x00000000，大小 4KB(0x1000)；栈顶在 RAM 顶端。
 *   由 RISC-V 交叉工具链使用（本仓库未安装，仅提供源码）。
 * ==========================================================================*/
MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00001000
}

ENTRY(_start)

SECTIONS
{
    . = ORIGIN(RAM);

    .text : {
        *(.text.start)
        *(.text)
    } > RAM

    .rodata : { *(.rodata) } > RAM
    .data   : { *(.data)   } > RAM
    .bss    : {
        _bss_start = .;
        *(.bss)
        _bss_end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
