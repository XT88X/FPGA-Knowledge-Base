/*
 * ch1_hello.c — 在教学型 RV32I 软核上通过 UART 打印 "Hello, RISC-V!\n"
 *
 * 硬件对应 ch1_riscv_soc.v：
 *   UART 数据寄存器 = 0x1000_0000，写一个字节即"打印"一个字符。
 *   （本最小系统里没有发送缓冲/状态寄存器，直接写即可；
 *     上板接真实 UART 发送器后，这里就是裸机 printf 的底层 putchar。）
 *
 * 构建命令（本机未安装工具链，仅给出命令与预期）：
 *   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -O2 \
 *       -T ch1_link.ld -nostdlib -o ch1_hello.elf ch1_startup.S ch1_hello.c
 *   riscv-none-elf-objcopy -O verilog ch1_hello.elf ch1_firmware.hex
 *   # 或用 -O binary + 自己转 mem 十六进制
 */

#define UART_BASE (*(volatile unsigned int *)0x10000000U)

/* 裸机 putchar：直接往 UART 数据寄存器写一个字节 */
static void putchar(char c)
{
    if (c == '\n')
        UART_BASE = (unsigned int)'\r';   /* 串口习惯：换行前先回车 */
    UART_BASE = (unsigned int)c;
}

static void puts(const char *s)
{
    while (*s)
        putchar(*s++);
}

int main(void)
{
    const char *msg = "Hello, RISC-V softcore!\n";
    puts(msg);

    /* 再打印一个简单数字：1+2+...+10 = 55 = '7' 的偏移演示 */
    volatile unsigned int sum = 0;
    for (int i = 1; i <= 10; i++)
        sum += (unsigned int)i;
    /* 55 -> 字符 '7'(0x37) 的低字节演示 */
    putchar((char)('0' + (sum / 10)));   /* 打印 '5' */
    putchar((char)('0' + (sum % 10)));   /* 打印 '5' */
    putchar('\n');

    while (1) { /* 死循环 */ }
    return 0;
}
