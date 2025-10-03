#!/bin/bash
echo "开始应用 HNAT 支持补丁..."

# 1. 首先检查源码结构
echo "检查源码目录结构..."
ls -la target/linux/ramips/
ls -la target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/ 2>/dev/null || echo "Mediatek 驱动目录不存在"

# 2. 创建必要的目录
echo "创建驱动目录..."
mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/

# 3. 复制驱动源码（如果存在）
if [ -d "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" ]; then
    echo "复制 HNAT 驱动源码..."
    cp -r target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat target/linux/ramips/files/drivers/net/ethernet/mediatek/
else
    echo "警告: Mediatek HNAT 驱动源码不存在，可能需要从其他地方获取"
fi

# 4. 添加设备树节点到 mt7621.dtsi
echo "添加 HNAT 设备树节点..."
# 先备份原文件
cp target/linux/ramips/dts/mt7621.dtsi target/linux/ramips/dts/mt7621.dtsi.backup

# 使用 sed 在合适的位置插入 HNAT 节点
sed -i '/cpuintc: interrupt-controller@1fb0000/a \
\n\thnat: hnat@1e100000 {\n\t\tcompatible = "mediatek,mtk-hnat_v1";\n\t\treg = <0x1e100000 0x3000>;\n\t\tstatus = "disabled";\n\t};' target/linux/ramips/dts/mt7621.dtsi

# 5. 在 HC5962 设备树中启用 HNAT
echo "在 HC5962 设备树中启用 HNAT..."
if [ -f "target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts" ]; then
    echo "&hnat { status = \"okay\"; };" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
else
    echo "警告: HC5962 设备树文件不存在"
fi

# 6. 添加内核配置
echo "添加 HNAT 内核配置..."
if [ -f "target/linux/ramips/mt7621/config-6.6" ]; then
    echo "CONFIG_NET_MEDIATEK_HNAT=m" >> target/linux/ramips/mt7621/config-6.6
else
    echo "警告: MT7621 内核配置文件不存在"
fi

# 7. 添加内核模块定义
echo "添加 HNAT 内核模块定义..."
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

echo "HNAT 补丁应用完成！"
