#!/bin/bash


echo "检测内核配置..."
if ! grep -q "CONFIG_NET_MEDIATEK_HNAT" target/linux/ramips/mt7621/config-6.6; then
    echo "❌ 内核配置不存在"
else
    echo "✅  内核配置已存在"
fi


$(eval $(call KernelPackage,mtk-hnat))
EOF
    echo "✅ 内核模块定义已添加"
else
    echo "⚠️  内核模块定义已存在"
fi


echo ""
echo "=== 验证补丁应用结果 ==="
echo "1. HC5962 HNAT启用状态:"
if grep -q "&hnat" target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts; then
    echo "✅ HC5962 HNAT已启用"
    grep -A2 "&hnat" target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
else
    echo "❌ HC5962 HNAT未启用"
fi








