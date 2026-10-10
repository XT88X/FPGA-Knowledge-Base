/* =============================================================================
 * ch4_main.c — ch4 SoC 裸机 C 程序（定时器中断翻转 LED + 串口打印 + 轮询按键）
 *
 *  【说明】本文件需用 RISC-V 交叉工具链编译（本仓库环境未安装工具链，
 *          仅提供源码与寄存器地址宏）。仿真自检用的是手工编码的 ch4_firmware.hex。
 *
 *  地址映射（与 ch4_bus_mux.v / ch4_soc_top.v 一致）：
 *    0x20000000  UART_DATA   (写=发字节)
 *    0x20000004  UART_STATUS
 *    0x20000010  GPIO_DIR
 *    0x20000014  GPIO_OUT
 *    0x20000018  GPIO_IN
 *    0x20000020  TIMER_CTRL
 *    0x20000024  TIMER_CMP
 *    0x20000028  TIMER_CNT
 *    0x2000002C  TIMER_CLR
 *    0x20000030  INTE
 *    0x20000034  INTF
 * ==========================================================================*/
#define UART_DATA   (*(volatile unsigned int *)0x20000000)
#define UART_STAT   (*(volatile unsigned int *)0x20000004)
#define GPIO_DIR    (*(volatile unsigned int *)0x20000010)
#define GPIO_OUT    (*(volatile unsigned int *)0x20000014)
#define GPIO_IN     (*(volatile unsigned int *)0x20000018)
#define TIMER_CTRL  (*(volatile unsigned int *)0x20000020)
#define TIMER_CMP   (*(volatile unsigned int *)0x20000024)
#define TIMER_CLR   (*(volatile unsigned int *)0x2000002C)
#define INTE        (*(volatile unsigned int *)0x20000030)
#define INTF        (*(volatile unsigned int *)0x20000034)

static void putchar(char c) { UART_DATA = (unsigned char)c; }
static void puts(const char *s) { while (*s) putchar(*s++); }

/* 定时器中断 ISR（由 _trap_entry 调用）：翻转 LED，清中断标志 */
void isr_timer(void) {
    GPIO_OUT ^= 0x1;     /* 翻转 LED */
    TIMER_CLR = 1;       /* 写清中断标志 */
}

int main(void) {
    GPIO_DIR = 0xFF;              /* GPIO 全部输出 */
    puts("Hello from ch4 SoC!\r\n");

    TIMER_CMP  = 1000;           /* 定时器周期 */
    TIMER_CTRL = 1;              /* 启动定时器 */
    INTE       = 1;              /* 使能定时器中断 */

    /* 主循环：轮询按键(GPIO_IN bit0)，按下则打印，并镜像输入到输出 */
    while (1) {
        unsigned int in = GPIO_IN;
        GPIO_OUT = in;           /* 镜像输入到输出 */
        if (in & 0x1) {
            putchar('B');         /* 按键按下 */
        }
    }
    return 0;
}
