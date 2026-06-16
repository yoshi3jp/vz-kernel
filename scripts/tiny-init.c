/* SPDX-License-Identifier: MIT
 * Tiny architecture-native init for CI smoke tests.
 *
 * This deliberately avoids libc and BusyBox so GitHub Actions does not need
 * dpkg multiarch or foreign-architecture packages.  It only proves that the
 * kernel can execute a target-architecture userspace ELF from initramfs.
 */

typedef unsigned long usize;

static usize cstr_len(const char *s)
{
	usize n = 0;
	while (s[n])
		n++;
	return n;
}

#if defined(__x86_64__)
#define SYS_write 1
#define SYS_reboot 169
#define SYS_exit 60

static long syscall1(long nr, long a0)
{
	long ret;
	register long rax __asm__("rax") = nr;
	register long rdi __asm__("rdi") = a0;
	__asm__ volatile("syscall"
	                 : "=a"(ret)
	                 : "r"(rax), "r"(rdi)
	                 : "rcx", "r11", "memory");
	return ret;
}

static long syscall3(long nr, long a0, long a1, long a2)
{
	long ret;
	register long rax __asm__("rax") = nr;
	register long rdi __asm__("rdi") = a0;
	register long rsi __asm__("rsi") = a1;
	register long rdx __asm__("rdx") = a2;
	__asm__ volatile("syscall"
	                 : "=a"(ret)
	                 : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx)
	                 : "rcx", "r11", "memory");
	return ret;
}

static long syscall4(long nr, long a0, long a1, long a2, long a3)
{
	long ret;
	register long rax __asm__("rax") = nr;
	register long rdi __asm__("rdi") = a0;
	register long rsi __asm__("rsi") = a1;
	register long rdx __asm__("rdx") = a2;
	register long r10 __asm__("r10") = a3;
	__asm__ volatile("syscall"
	                 : "=a"(ret)
	                 : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10)
	                 : "rcx", "r11", "memory");
	return ret;
}

#elif defined(__aarch64__)
#define SYS_write 64
#define SYS_reboot 142
#define SYS_exit 93

static long syscall1(long nr, long a0)
{
	register long x0 __asm__("x0") = a0;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0"
	                 : "+r"(x0)
	                 : "r"(x8)
	                 : "memory");
	return x0;
}

static long syscall3(long nr, long a0, long a1, long a2)
{
	register long x0 __asm__("x0") = a0;
	register long x1 __asm__("x1") = a1;
	register long x2 __asm__("x2") = a2;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0"
	                 : "+r"(x0)
	                 : "r"(x1), "r"(x2), "r"(x8)
	                 : "memory");
	return x0;
}

static long syscall4(long nr, long a0, long a1, long a2, long a3)
{
	register long x0 __asm__("x0") = a0;
	register long x1 __asm__("x1") = a1;
	register long x2 __asm__("x2") = a2;
	register long x3 __asm__("x3") = a3;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0"
	                 : "+r"(x0)
	                 : "r"(x1), "r"(x2), "r"(x3), "r"(x8)
	                 : "memory");
	return x0;
}

#else
#error unsupported architecture
#endif

#define LINUX_REBOOT_MAGIC1 0xfee1deadUL
#define LINUX_REBOOT_MAGIC2 672274793UL
#define LINUX_REBOOT_CMD_POWER_OFF 0x4321fedcUL

void _start(void)
{
	static const char msg[] = "DS_KERNEL_BOOT_OK\n";

	syscall3(SYS_write, 1, (long)msg, (long)cstr_len(msg));
	syscall4(SYS_reboot,
	         LINUX_REBOOT_MAGIC1,
	         LINUX_REBOOT_MAGIC2,
	         LINUX_REBOOT_CMD_POWER_OFF,
	         0);
	syscall1(SYS_exit, 0);

	for (;;)
		;
}
