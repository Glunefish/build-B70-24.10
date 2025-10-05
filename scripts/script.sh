#!/bin/bash

set -e

echo "🔍 HNAT 模块编译检测脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测函数
check_hnat_source() {
    echo -e "${BLUE}📁 检查 HNAT 源码...${NC}"
    
    # 检查内核驱动源码
    if [ -d "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" ]; then
        echo -e "${GREEN}✅ HNAT 驱动源码存在${NC}"
        echo "文件列表:"
        ls -la target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat/
    else
        echo -e "${RED}❌ HNAT 驱动源码不存在${NC}"
        echo "搜索所有 hnat 相关文件:"
        find . -name "*hnat*" -type f | head -10
        return 1
    fi
    
    # 检查模块定义
    echo -e "${BLUE}📄 检查模块定义...${NC}"
    if grep -q "mtk-hnat" target/linux/ramips/modules.mk; then
        echo -e "${GREEN}✅ 找到 mtk-hnat 模块定义${NC}"
        grep -A5 "mtk-hnat" target/linux/ramips/modules.mk
    else
        echo -e "${RED}❌ 未找到 mtk-hnat 模块定义${NC}"
        return 1
    fi
    
    # 检查内核配置
    echo -e "${BLUE}⚙️ 检查内核配置...${NC}"
    if grep -q "CONFIG_NET_MEDIATEK_HNAT=m" .config; then
        echo -e "${GREEN}✅ HNAT 配置为模块${NC}"
    else
        echo -e "${YELLOW}⚠️ HNAT 未配置为模块${NC}"
        grep -i "mediatek.*hnat" .config || echo "未找到 HNAT 相关配置"
    fi
    
    return 0
}

monitor_hnat_compile() {
    echo -e "${BLUE}🚀 开始监控 HNAT 编译...${NC}"
    
    local max_wait=600  # 10分钟
    local hnat_found=false
    
    for i in $(seq 1 $max_wait); do
        # 搜索 .ko 文件
        local ko_file=$(find . -name "mtkhnat.ko" -type f 2>/dev/null | head -1)
        if [ -z "$ko_file" ]; then
            ko_file=$(find . -name "hnat.ko" -type f 2>/dev/null | head -1)
        fi
        
        if [ -n "$ko_file" ] && [ "$hnat_found" = "false" ]; then
            echo -e "${GREEN}🎉🎉🎉 HNAT 模块编译成功！ 🎉🎉🎉${NC}"
            echo "=========================================="
            echo "📁 文件路径: $ko_file"
            echo "📊 文件大小: $(ls -lh "$ko_file" | awk '{print $5}')"
            echo "🔍 绝对路径: $(pwd)/$ko_file"
            echo ""
            
            echo "📋 文件详细信息:"
            ls -la "$ko_file"
            echo ""
            
            echo "📁 所在目录内容:"
            ls -la "$(dirname "$ko_file")"
            echo ""
            
            hnat_found=true
            break
        fi
        
        # 每5秒检查一次
        sleep 5
        
        # 显示进度
        if [ $((i % 12)) -eq 0 ]; then
            echo "⏳ 监控中... ($((i/12)) 分钟)"
        fi
    done
    
    if [ "$hnat_found" = "false" ]; then
        echo -e "${RED}❌ 超时未找到 HNAT 模块${NC}"
        echo "=========================================="
        
        # 检查编译错误
        echo -e "${YELLOW}🔍 检查编译日志...${NC}"
        if [ -f "/tmp/build.log" ]; then
            grep -i "error" /tmp/build.log | grep -i "hnat\|mtk_hnat" | head -5 || echo "未找到 HNAT 相关错误"
        fi
        
        # 检查是否生成了 .o 文件
        echo -e "${YELLOW}🔍 检查编译中间文件...${NC}"
        find . -name "*.o" -path "*/mtk_hnat/*" 2>/dev/null | head -5 || echo "未找到编译中间文件"
        
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    echo -e "${BLUE}=== HNAT 检测开始 ===${NC}"
    
    # 检查源码
    if ! check_hnat_source; then
        echo -e "${RED}❌ HNAT 源码检查失败${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}=== 开始编译监控 ===${NC}"
    
    # 监控编译
    if ! monitor_hnat_compile; then
        echo -e "${RED}❌ HNAT 模块编译失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ HNAT 检测完成${NC}"
    return 0
}

# 执行主函数
main "$@"
