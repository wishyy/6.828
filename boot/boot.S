#include <inc/mmu.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG, 0x8         # kernel code segment selector
.set PROT_MODE_DSEG, 0x10        # kernel data segment selector
.set CR0_PE_ON,      0x1         # protected mode enable flag

.globl start
start:			      #程序入口
  .code16                     # Assemble for 16-bit mode指导生成16位汇编代码
  cli                         # Disable interrupts 屏蔽中断
  cld                         # String operations increment 串传递从低址到高址

  # Set up the important data segment registers (DS, ES, SS).  设置重要的段寄存器为0
  xorw    %ax,%ax             # Segment number zero
  movw    %ax,%ds             # -> Data Segment
  movw    %ax,%es             # -> Extra Segment
  movw    %ax,%ss             # -> Stack Segment

  # Enable A20:
  #   For backwards compatibility with the earliest PCs, physical
  #   address line 20 is tied low, so that addresses higher than
  #   1MB wrap around to zero by default.  This code undoes this.
seta20.1:
  inb     $0x64,%al               # Wait for not busy   等待缓冲区可用
  testb   $0x2,%al		  #检测bit1  如果bit1=1 输入缓冲区满
  jnz     seta20.1	 	  

  movb    $0xd1,%al               # 0xd1 -> port 0x64
  outb    %al,$0x64               #准备写入输入端口

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2

  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60               #写入0xdf，打开A20

  # Switch from real to protected mode, using a bootstrap GDT
  # and segment translation that makes virtual addresses 
  # identical to their physical addresses, so that the 
  # effective memory map does not change during the switch.

  lgdt    gdtdesc    #加载全局操作符表
  			#在机器刚加电或者是处理器复位后，表基址默认被置为0，
  			#表限长则默认被置为0xFFFF。在保护模式初始化的过程中，
  			#必须给GDTR加载新的值。lgdt指令为GDTR加载新值。
  movl    %cr0, %eax #读取控制寄存器0的值，其bit0为允许保护模式位
  orl     $CR0_PE_ON, %eax #Set PE 将允许保护模式为 置为1
  movl    %eax, %cr0  #设置控制寄存器0
  
  # Jump to next instruction, but in 32-bit code segment.
  # Switches processor into 32-bit mode.
  ljmp    $PROT_MODE_CSEG, $protcseg   #通过ljmp指令（跳转至下一条指令）进入保护模式

  .code32                     # Assemble for 32-bit mode 指导生成32位汇编代码
protcseg:
  # Set up the protected-mode data segment registers   设置保护模式的数据段寄存器
  movw    $PROT_MODE_DSEG, %ax    # Our data segment selector
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS
  movw    %ax, %ss                # -> SS: Stack Segment
  
  # Set up the stack pointer and call into C.         设置栈指针并且调用C
  movl    $start, %esp    #注意栈的延伸方向和代码段相反
  call bootmain		  #调用main.c中的bootmain函数

  # If bootmain returns (it shouldn't), loop.
spin:
  jmp spin

# Bootstrap GDT   引导GDT
.p2align 2                                # force 4 byte alignment
gdt:
  SEG_NULL				# null seg  默认第一个段描述符为空
  SEG(STA_X|STA_R, 0x0, 0xffffffff)	# code seg  设置代码段描述符
  SEG(STA_W, 0x0, 0xffffffff)	        # data seg  设置数据段描述符

gdtdesc:				# 用于设置全局段描述符寄存器
  .word   0x17                            # sizeof(gdt) - 1  # Size of gdt
  .long   gdt                             # address gdt # Base address of gdt

