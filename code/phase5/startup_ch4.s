/* =============================================================================
 * startup_ch4.s — ch4 SoC 裸机启动文件（复位与中断向量）
 *
 *  由 RISC-V 交叉工具链构建（本仓库未安装，仅提供源码）。
 *  复位入口：设栈、清 .bss、调 main()。
 *  中断向量：TRAP_VEC=0x100，保存现场(教学版仅用 x5 存返回地址)，
 *            跳 C 层 isr_timer()，返回后用 x5 回 PC。
 * ==========================================================================*/
    .section .text.start
    .globl _start
_start:
    /* 设栈顶（链接脚本给出 _stack_top） */
    la      sp, _stack_top

    /* 清 .bss */
    la      t0, _bss_start
    la      t1, _bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:

    /* 跳 main */
    call    main

    /* main 不应返回；若返回则在此死循环 */
3:  j       3b

/* ---- 中断向量入口（地址 0x100，由硬件取指跳来）---- */
    .org    0x100
    .globl _trap_entry
_trap_entry:
    /* 教学简化：硬件已把返回地址写入 x5；这里直接调 C 层 ISR */
    call    isr_timer
    /* 返回：x5 即被打断指令的下一条地址 */
    jr      x5
