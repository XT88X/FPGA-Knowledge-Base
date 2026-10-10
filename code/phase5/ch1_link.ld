/*
 * ch1_link.ld — RV32I 最小链接脚本（对应 ch1_riscv_soc.v 的内存映射）
 *   内存：0x0000_0000 起 4KB 统一 RAM（代码+数据+栈）
 *   UART 数据寄存器：0x1000_0000（写一个字节即打印一个字符）
 */
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.startup)   /* _start 最先 */
        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > RAM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
    } > RAM

    .data : {
        *(.data)
        *(.data.*)
        . = ALIGN(4);
    } > RAM

    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /* 栈顶放在 RAM 末尾（4KB=0x1000）*/
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
