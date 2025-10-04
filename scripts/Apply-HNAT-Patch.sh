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








