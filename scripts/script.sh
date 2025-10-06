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
        echo "模块定义内容:"
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
        return 1
    fi
    
    return 0
}

monitor_hnat_compile() {
    echo -e "${BLUE}🚀 开始实时监控 HNAT 编译过程...${NC}"
    
    local max_wait=600  # 10分钟
    local hnat_found=false
    local hnat_compiling=false
    local last_check_time=$(date +%s)
    
    for i in $(seq 1 $max_wait); do
        # 1. 实时搜索 .ko 文件
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
            return 0
        fi
        
        # 2. 实时检查编译日志中的 HNAT 活动
        if [ -f "/tmp/build.log" ]; then
            local current_time=$(date +%s)
            if [ $((current_time - last_check_time)) -ge 10 ]; then  # 每10秒检查一次日志
                last_check_time=$current_time
                
                # 检查 HNAT 编译开始
                if tail -n 100 /tmp/build.log | grep -q "hnat\.c\|mtk_hnat.*\.o"; then
                    if [ "$hnat_compiling" = "false" ]; then
                        echo -e "${GREEN}📝 检测到 HNAT 开始编译...${NC}"
                        hnat_compiling=true
                    fi
                    # 显示具体的编译信息
                    echo "编译进度: $(tail -n 100 /tmp/build.log | grep "hnat\.c\|mtk_hnat" | tail -1)"
                fi
                
                # 检查 HNAT 编译错误
                if tail -n 100 /tmp/build.log | grep -q -i "error.*hnat\|error.*mtk_hnat"; then
                    echo -e "${RED}❌ 检测到 HNAT 编译错误:${NC}"
                    tail -n 100 /tmp/build.log | grep -i -A3 -B3 "error.*hnat\|error.*mtk_hnat" | head -10
                    return 1
                fi
                
                # 检查 HNAT 链接信息
                if tail -n 100 /tmp/build.log | grep -q -i "linking.*hnat\|mtkhnat\.ko"; then
                    echo -e "${GREEN}🔗 检测到 HNAT 模块链接...${NC}"
                    tail -n 100 /tmp/build.log | grep -i "linking.*hnat\|mtkhnat\.ko" | tail -2
                fi
            fi
        fi
        
        # 3. 实时检查编译中间文件
        local o_files=$(find . -name "*.o" -path "*/mtk_hnat/*" 2>/dev/null | head -3)
        if [ -n "$o_files" ] && [ "$hnat_compiling" = "false" ]; then
            echo -e "${GREEN}⚙️ 检测到 HNAT 编译中间文件 (.o 文件)${NC}"
            echo "$o_files"
            hnat_compiling=true
        fi
        
        sleep 5
        
        # 显示进度
        if [ $((i % 12)) -eq 0 ]; then
            echo "⏳ 监控中... ($((i/12)) 分钟)"
        fi
    done
    
    # 监控超时后的详细分析
    echo -e "${RED}❌ 超时未找到 HNAT 模块${NC}"
    echo "=========================================="
    
    echo -e "${YELLOW}🔍 详细错误分析:${NC}"
    
    # 检查编译日志中的错误
    if [ -f "/tmp/build.log" ]; then
        echo "=== 编译错误汇总 ==="
        grep -i "error" /tmp/build.log | grep -i "hnat\|mtk_hnat" | head -10 || echo "未找到 HNAT 相关编译错误"
        
        echo ""
        echo "=== HNAT 相关日志 ==="
        grep -i "hnat\|mtk_hnat" /tmp/build.log | tail -20 || echo "无 HNAT 相关日志"
    fi
    
    # 检查编译中间文件
    echo ""
    echo "=== 编译中间文件检查 ==="
    find . -name "*.o" -path "*/mtk_hnat/*" 2>/dev/null | head -10 || echo "未找到编译中间文件"
    
    # 检查所有相关文件
    echo ""
    echo "=== 所有 HNAT 相关文件 ==="
    find . -name "*hnat*" -type f 2>/dev/null | head -15
    
    return 1
}

# 主函数
main() {
    echo -e "${BLUE}=== HNAT 检测开始 ===${NC}"
    
    # 检查源码和配置
    if ! check_hnat_source; then
        echo -e "${RED}❌ HNAT 源码检查失败，无法继续${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}=== 开始实时编译监控 ===${NC}"
    
    # 监控编译过程
    if ! monitor_hnat_compile; then
        echo -e "${RED}❌ HNAT 模块编译失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ HNAT 检测完成${NC}"
    return 0
}

# 执行主函数
main "$@"
