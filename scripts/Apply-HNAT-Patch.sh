echo "=== 检查编译结果 ==="

# 查找生成的HNAT相关文件
find build_dir/ -name "*hnat*" -type f 2>/dev/null

# 检查是否生成了.ko文件
find build_dir/ -name "mtk_hnat.ko" -type f 2>/dev/null

# 检查编译日志
echo "=== 编译日志摘要 ==="
grep -i "hnat" build_dir/target-*/linux-ramips_*/linux-*.log 2>/dev/null | tail -10
