#!/bin/bash

echo "=== 深入HNAT诊断 ==="

# 检查内核实际配置
echo "1. 检查内核实际配置..."
if [ -d "build_dir" ]; then
    kernel_config=$(find build_dir -name ".config" -path "*/linux-*" | head -1)
    if [ -f "$kernel_config" ]; then
        echo "内核配置文件: $kernel_config"
        grep -i "hnat" "$kernel_config" || echo "  未找到HNAT配置"
    else
        echo "❌ 未找到内核配置文件"
    fi
fi

echo ""

# 检查Kconfig选项
echo "2. 检查Kconfig选项..."
kconfig_files=$(find build_dir -name "Kconfig" -path "*/mediatek/*" 2>/dev/null)
if [ -n "$kconfig_files" ]; then
    echo "找到的Kconfig文件:"
    echo "$kconfig_files"
    for file in $kconfig_files; do
        echo "  检查 $file:"
        grep -i "hnat" "$file" 2>/dev/null && echo "    ✅ 找到HNAT选项" || echo "    ❌ 未找到HNAT选项"
    done
else
    echo "❌ 未找到mediatek的Kconfig文件"
fi

echo ""

# 检查Makefile
echo "3. 检查Makefile..."
makefiles=$(find build_dir -name "Makefile" -path "*/mediatek/*" 2>/dev/null)
if [ -n "$makefiles" ]; then
    for file in $makefiles; do
        echo "  检查 $file:"
        grep -i "hnat" "$file" 2>/dev/null && echo "    ✅ 找到HNAT编译目标" || echo "    ❌ 未找到HNAT编译目标"
    done
else
    echo "❌ 未找到mediatek的Makefile"
fi

echo ""
echo "=== 诊断完成 ==="
