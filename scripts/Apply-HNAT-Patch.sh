#!/bin/bash
echo "=== 应用正确的HNAT支持补丁（仅在HC5962启用）==="

# 0. 备份原始文件
echo "备份原始文件..."
cp target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts.orig 2>/dev/null || true
cp target/linux/ramips/mt7621/config-6.6 target/linux/ramips/mt7621/config-6.6.orig
cp target/linux/ramips/modules.mk target/linux/ramips/modules.mk.orig

# 1. 首先检查mt7621.dtsi中是否已经有HNAT节点
echo "1. 检查mt7621.dtsi中是否已有HNAT节点..."
if grep -q "hnat@" target/linux/ramips/dts/mt7621.dtsi; then
    echo "✅ mt7621.dtsi中已有HNAT节点，无需添加"
else
    echo "⚠️  mt7621.dtsi中没有HNAT节点，需要添加..."
    # 在mt7621.dtsi中添加HNAT节点定义
    SOC_END=$(grep -n "^[[:space:]]*};[[:space:]]*$" target/linux/ramips/dts/mt7621.dtsi | head -1 | cut -d: -f1)
    if [ -n "$SOC_END" ]; then
        sed -i "${SOC_END}i\\\\thnat: hnat@1e100000 {\\n\\t\\tcompatible = \\\"mediatek,mtk-hnat\\\";\\n\\t\\treg = <0x1e100000 0x300000>;\\n\\t\\tstatus = \\\"disabled\\\";\\n\\t};" target/linux/ramips/dts/mt7621.dtsi
        echo "✅ 已在mt7621.dtsi中添加HNAT节点"
    fi
fi

# 2. 在HC5962设备树中启用HNAT
echo "2. 在HC5962设备树中启用HNAT..."
if [ -f "target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts" ]; then
    # 删除可能存在的旧配置
    sed -i '/&hnat/d' target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    
    # 在合适的位置添加HNAT启用配置（通常在文件末尾）
    echo "" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    echo "&hnat {" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    echo "	status = \"okay\";" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    echo "};" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    
    echo "✅ HC5962 HNAT已启用"
else
    echo "❌ HC5962设备树文件不存在"
    exit 1
fi

# 3. 创建驱动目录并复制源码
echo "3. 设置驱动源码..."
mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/
if [ -d "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" ]; then
    cp -r target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat target/linux/ramips/files/drivers/net/ethernet/mediatek/
    echo "✅ 驱动源码复制成功"
else
    echo "⚠️  驱动源码不存在，创建基本结构..."
    mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat
    cat > target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat/Makefile << 'EOF'
obj-$(CONFIG_NET_MEDIATEK_HNAT) += mtk_hnat.o
mtk_hnat-objs := hnat.o
EOF
fi

# 4. 添加内核配置
echo "4. 添加内核配置..."
if ! grep -q "CONFIG_NET_MEDIATEK_HNAT" target/linux/ramips/mt7621/config-6.6; then
    echo "CONFIG_NET_MEDIATEK_HNAT=m" >> target/linux/ramips/mt7621/config-6.6
    echo "✅ 内核配置已添加"
else
    echo "⚠️  内核配置已存在"
fi

# 5. 添加内核模块定义
echo "5. 添加内核模块定义..."
if ! grep -q "KernelPackage/mtk-hnat" target/linux/ramips/modules.mk; then
    cat >> target/linux/ramips/modules.mk << 'EOF'

define KernelPackage/mtk-hnat
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=MediaTek MT762x HW NAT driver
  DEPENDS:=@TARGET_ramips_mt7621 +kmod-nf-conntrack
  KCONFIG:=CONFIG_NET_MEDIATEK_HNAT
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/mediatek/mtk_hnat/mtk_hnat.ko
  AUTOLOAD:=$(call AutoLoad,50,mtk_hnat)
endef

define KernelPackage/mtk-hnat/description
  Kernel module for MediaTek MT762x HW NAT offloading
endef

$(eval $(call KernelPackage,mtk-hnat))
EOF
    echo "✅ 内核模块定义已添加"
else
    echo "⚠️  内核模块定义已存在"
fi

# 6. 验证补丁应用
echo ""
echo "=== 验证补丁应用结果 ==="
echo "1. HC5962 HNAT启用状态:"
if grep -q "&hnat" target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts; then
    echo "✅ HC5962 HNAT已启用"
    grep -A2 "&hnat" target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
else
    echo "❌ HC5962 HNAT未启用"
fi

echo ""
echo "2. 内核配置:"
grep "CONFIG_NET_MEDIATEK_HNAT" target/linux/ramips/mt7621/config-6.6 || echo "❌ 内核配置未找到"

echo ""
echo "3. 模块定义:"
grep "KernelPackage/mtk-hnat" target/linux/ramips/modules.mk || echo "❌ 模块定义未找到"

echo ""
echo "4. 驱动文件:"
find target/linux/ramips/files -name "mtk_hnat" -type d 2>/dev/null | head -1 || echo "⚠️  驱动目录未找到"

echo ""
echo "=== 设备树语法验证 ==="
if command -v dtc &> /dev/null; then
    if [ -f "target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts" ]; then
        dtc -I fs -O dts target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts > /dev/null 2>&1 && echo "✅ HC5962 dts 语法正确" || echo "❌ HC5962 dts 语法错误"
    fi
else
    echo "⚠️  dtc不可用，跳过语法检查"
fi

echo ""
echo "=== HNAT补丁应用完成 ==="
echo ""
#!/bin/bash
echo "=== 强制编译 HNAT 模块 ==="

# 1. 首先检查当前状态
echo "1. 检查当前配置状态..."
echo "内核配置:"
grep "CONFIG_NET_MEDIATEK_HNAT" .config 2>/dev/null || echo "❌ 不在 .config 中"

echo "模块定义:"
grep "KernelPackage/mtk-hnat" target/linux/ramips/modules.mk 2>/dev/null && echo "✅ 模块定义存在" || echo "❌ 模块定义不存在"

# 2. 确保配置正确
echo "2. 确保配置正确..."
# 清理临时配置
rm -rf tmp/

# 强制在 .config 中添加 HNAT 配置
if ! grep -q "CONFIG_NET_MEDIATEK_HNAT" .config 2>/dev/null; then
    echo "CONFIG_NET_MEDIATEK_HNAT=m" >> .config
    echo "✅ 已添加 HNAT 配置到 .config"
fi

# 3. 确保模块定义正确且完整
echo "3. 修复模块定义..."
# 删除可能不完整的模块定义
sed -i '/KernelPackage\/mtk-hnat/,/KernelPackage\/mtk-hnat/d' target/linux/ramips/modules.mk

# 添加完整的模块定义
cat >> target/linux/ramips/modules.mk << 'EOF'

define KernelPackage/mtk-hnat
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=MediaTek HNAT support
  DEPENDS:=@TARGET_ramips_mt7621 +kmod-nf-conntrack
  KCONFIG:=CONFIG_NET_MEDIATEK_HNAT
  FILES:=$(LINUX_DIR)/drivers/net/ethernet/mediatek/mtk_hnat/mtk_hnat.ko
  AUTOLOAD:=$(call AutoLoad,51,mtk_hnat)
endef

define KernelPackage/mtk-hnat/description
  This driver supports the HNAT (Hardware NAT) function of MediaTek SoCs.
endef

$(eval $(call KernelPackage,mtk-hnat))
EOF
echo "✅ 模块定义已修复"

# 4. 确保驱动源码可编译
echo "4. 检查驱动源码..."
if [ ! -f "target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c" ]; then
    echo "❌ 驱动源码不存在，从 mediatek 复制..."
    mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat
    if [ -f "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c" ]; then
        cp target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat/* target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat/
        echo "✅ 驱动源码已复制"
    else
        echo "❌ 找不到原始驱动文件"
        exit 1
    fi
fi

# 5. 创建必要的 Makefile
echo "5. 创建驱动 Makefile..."
cat > target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat/Makefile << 'EOF'
# SPDX-License-Identifier: GPL-2.0
obj-$(CONFIG_NET_MEDIATEK_HNAT) += mtk_hnat.o

mtk_hnat-objs := hnat.o

ccflags-y += -I$(src)
EOF

# 6. 创建编译补丁
echo "6. 创建编译补丁..."
mkdir -p target/linux/ramips/patches-6.6
cat > target/linux/ramips/patches-6.6/999-mtk-hnat.patch << 'EOF'
--- a/drivers/net/ethernet/mediatek/Makefile
+++ b/drivers/net/ethernet/mediatek/Makefile
@@ -5,3 +5,4 @@
 obj-$(CONFIG_NET_MEDIATEK_SOC_WED) += mtk_wed.o
 obj-$(CONFIG_NET_MEDIATEK_SOC) += mtk_eth.o
 obj-$(CONFIG_NET_MEDIATEK_STAR_EMAC) += mtk_star_emac.o
+obj-$(CONFIG_NET_MEDIATEK_HNAT) += mtk_hnat/
EOF

# 7. 重新生成配置
echo "7. 重新生成配置..."
make defconfig

# 检查配置是否生效
if grep -q "CONFIG_NET_MEDIATEK_HNAT=m" .config; then
    echo "✅ HNAT 配置已生效"
else
    echo "❌ HNAT 配置未生效"
    exit 1
fi

echo "✅ 修复完成，准备编译"

