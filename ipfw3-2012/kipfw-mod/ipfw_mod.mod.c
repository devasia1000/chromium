#include <linux/module.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

MODULE_INFO(vermagic, VERMAGIC_STRING);

struct module __this_module
__attribute__((section(".gnu.linkonce.this_module"))) = {
 .name = KBUILD_MODNAME,
 .init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
 .exit = cleanup_module,
#endif
 .arch = MODULE_ARCH_INIT,
};

static const struct modversion_info ____versions[]
__used
__attribute__((section("__versions"))) = {
	{ 0x8495e121, "module_layout" },
	{ 0x5a34a45c, "__kmalloc" },
	{ 0x405c1144, "get_seconds" },
	{ 0x3ec8886f, "param_ops_int" },
	{ 0xc996d097, "del_timer" },
	{ 0x79aa04a2, "get_random_bytes" },
	{ 0x1637ff0f, "_raw_spin_lock_bh" },
	{ 0x10936a38, "nf_reinject" },
	{ 0xfb0e29f, "init_timer_key" },
	{ 0x2447533c, "ktime_get_real" },
	{ 0x91715312, "sprintf" },
	{ 0x7d11c268, "jiffies" },
	{ 0xe2d5255a, "strcmp" },
	{ 0xbf5846a5, "tcp_hashinfo" },
	{ 0xde0bdcff, "memset" },
	{ 0x27e1a049, "printk" },
	{ 0x2fa5a500, "memcmp" },
	{ 0xe52592a, "panic" },
	{ 0x7ec9bfbc, "strncpy" },
	{ 0xb4390f9a, "mcount" },
	{ 0x1cd4264d, "nf_unregister_queue_handler" },
	{ 0x85abc85f, "strncmp" },
	{ 0x672144bd, "strlcpy" },
	{ 0x4e1a803f, "sk_free" },
	{ 0xbe2c0274, "add_timer" },
	{ 0xd40dbb60, "init_net" },
	{ 0xee4f1906, "nf_unregister_hooks" },
	{ 0x3ff62317, "local_bh_disable" },
	{ 0xd50d6977, "nf_register_queue_handler" },
	{ 0xf400a72a, "__alloc_skb" },
	{ 0xba63339c, "_raw_spin_unlock_bh" },
	{ 0xf0fdf6cb, "__stack_chk_fail" },
	{ 0x27204690, "nf_unregister_sockopt" },
	{ 0x799aca4, "local_bh_enable" },
	{ 0xeabfc510, "pv_cpu_ops" },
	{ 0x44d77b61, "ip_route_output_flow" },
	{ 0x1d2e87c6, "do_gettimeofday" },
	{ 0xfdee7d42, "_raw_read_lock_bh" },
	{ 0xf37260ab, "_raw_read_unlock_bh" },
	{ 0x37a0cba, "kfree" },
	{ 0x236c8c64, "memcpy" },
	{ 0xea8a6c75, "param_ops_long" },
	{ 0xfcf466d3, "nf_register_hooks" },
	{ 0xfa30159a, "__ip_dev_find" },
	{ 0x68f3bb3b, "__inet_lookup_listener" },
	{ 0xb6d88281, "nf_register_sockopt" },
	{ 0x50720c5f, "snprintf" },
	{ 0xd80245f6, "skb_put" },
	{ 0xa2c56c31, "param_ops_ulong" },
	{ 0xc3fe87c8, "param_ops_uint" },
	{ 0xa0762918, "__inet_lookup_established" },
};

static const char __module_depends[]
__used
__attribute__((section(".modinfo"))) =
"depends=";


MODULE_INFO(srcversion, "D2844A56E6AE8A784E1E8CA");
