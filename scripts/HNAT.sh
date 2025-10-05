#!/bin/bash

set -e

echo "🔍 MT7621 HNAT 编译条件检测脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检测函数
check_condition() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "检查 $name... "
    
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ 通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        return 1
    fi
}

# 统计变量
total_checks=0
passed_checks=0

echo "📋 开始检测 HNAT 编译条件..."
echo ""

# 1. 检查内核配置
((total_checks++))
if check_condition "内核配置" "grep 'CONFIG_NET_MEDIATEK_HNAT' target/linux/ramips/mt7621/config-6.6" "CONFIG_NET_MEDIATEK_HNAT=m"; then
    ((passed_checks++))
fi

# 2. 检查包配置
((total_checks++))
if check_condition "包配置" "grep 'CONFIG_PACKAGE_kmod-mtk-hnat' target/linux/ramips/mt7621/config-6.6" "CONFIG_PACKAGE_kmod-mtk-hnat=y"; then
    ((passed_checks++))
fi

# 3. 检查模块定义
((total_checks++))
if check_condition "模块定义" "grep 'KernelPackage/mtk-hnat' target/linux/ramips/modules.mk" "KernelPackage/mtk-hnat"; then
    ((passed_checks++))
fi

# 4. 检查设备树基础节点
((total_checks++))
if check_condition "设备树基础节点" "grep 'hnat: hnat@1e100000' target/linux/ramips/dts/mt7621.dtsi" "hnat: hnat@1e100000"; then
    ((passed_checks++))
fi

# 5. 检查 HC5962 设备树配置
((total_checks++))
if check_condition "HC5962设备树配置" "grep '&hnat' target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts" "&hnat"; then
    ((passed_checks++))
fi

# 6. 检查主驱动 Makefile
((total_checks++))
if [ -f "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/Makefile" ]; then
    echo -e "检查 主驱动Makefile... ${GREEN}✓ 通过${NC}"
    ((passed_checks++))
else
    echo -e "检查 主驱动Makefile... ${RED}✗ 失败${NC}"
fi

# 7. 检查 HNAT 驱动文件
((total_checks++))
hnat_files=$(find target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat -name "*.c" 2>/dev/null | wc -l)
if [ "$hnat_files" -ge 5 ]; then
    echo -e "检查 HNAT驱动文件 ($hnat_files个文件)... ${GREEN}✓ 通过${NC}"
    ((passed_checks++))
else
    echo -e "检查 HNAT驱动文件 ($hnat_files个文件)... ${RED}✗ 失败${NC}"
fi

# 8. 检查 HNAT Makefile
((total_checks++))
if [ -f "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat/Makefile" ]; then
    echo -e "检查 HNAT Makefile... ${GREEN}✓ 通过${NC}"
    ((passed_checks++))
else
    echo -e "检查 HNAT Makefile... ${RED}✗ 失败${NC}"
fi

# 9. 检查兼容性匹配
((total_checks++))
if check_condition "兼容性匹配" "grep 'mediatek,mtk-hnat_v1' target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c" "mediatek,mtk-hnat_v1"; then
    ((passed_checks++))
fi

echo ""
echo "=========================================="
echo "📊 检测结果汇总:"
echo "   总检查项: $total_checks"
echo "   通过项: $passed_checks"
echo "   失败项: $((total_checks - passed_checks))"

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 所有条件检测通过！可以开始编译 HNAT。${NC}"
    exit 0
elif [ $passed_checks -ge 7 ]; then
    echo -e "${YELLOW}⚠️  大部分条件通过，但存在一些问题，建议检查失败项。${NC}"
    exit 1
else
    echo -e "${RED}❌ 多个条件检测失败，请先修复问题再编译。${NC}"
    exit 1
fi
