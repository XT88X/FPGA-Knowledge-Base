/*
 * ch1_startup.S — RV32I 最小启动汇编
 *   1) 设栈指针 sp = 0x1000（RAM 4KB 末尾，与链接脚本一致）
 *   2) 清零 .bss
 *   3) 跳 C 入口 main()
 *   4) main 返回后原地死循环
 *
 * 注意：lui rd, imm 含义是 rd = (imm << 12)；要得到 sp=0x1000，写 lui sp,1。
 */

    .section .text.startup, "ax"
    .globl _start
_start:
    /* sp = 0x1000（RAM 末尾）*/
    lui   sp, 1                  /* sp = 1 << 12 = 0x1000 */

    /* 清零 .bss：__bss_start .. __bss_end */
    la    t0, __bss_start
    la    t1, __bss_end
1:
    bge   t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:
    /* 调 main() */
    call  main

    /* main 返回后死循环 */
3:
    j     3b
