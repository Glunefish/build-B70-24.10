#!/bin/bash
echo "开始应用 HNAT 支持补丁..."

# 1. 创建必要的目录
echo "创建驱动目录..."
mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/

# 2. 复制驱动源码
if [ -d "target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" ]; then
    echo "复制 HNAT 驱动源码..."
    cp -r target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat target/linux/ramips/files/drivers/net/ethernet/mediatek/
else
    echo "警告: Mediatek HNAT 驱动源码不存在"
    # 创建基本的驱动文件结构
    mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat
    cat > target/linux/ramips/files/drivers/net/ethernet/mediatek/mtk_hnat/Makefile << 'EOF'
obj-$(CONFIG_NET_MEDIATEK_HNAT) += mtk_hnat.o
EOF
fi

# 3. 修复设备树节点 - 确保在正确的位置添加
echo "修复设备树节点定义..."

# 备份原文件
cp target/linux/ramips/dts/mt7621.dtsi target/linux/ramips/dts/mt7621.dtsi.backup

# 在合适的位置添加 hnat 节点（在 soc 节点内）
sed -i '/soc {/,/^};/{
    /ethernet@1e10000;/a\
\thnat: hnat@1e100000 {\
\t\tcompatible = "mediatek,mtk-hnat_v1";\
\t\treg = <0x1e100000 0x3000>;\
\t\tstatus = "disabled";\
\t};
}' target/linux/ramips/dts/mt7621.dtsi

# 4. 在 HC5962 设备树中启用 HNAT
echo "在 HC5962 设备树中启用 HNAT..."
if [ -f "target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts" ]; then
    # 先检查是否已经存在
    if ! grep -q "&hnat" target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts; then
        echo "&hnat { status = \"okay\"; };" >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts
    fi
else
    echo "警告: HC5962 设备树文件不存在"
fi

# 5. 添加内核配置
echo "添加 HNAT 内核配置..."
if [ -f "target/linux/ramips/mt7621/config-6.6" ]; then
    if ! grep -q "CONFIG_NET_MEDIATEK_HNAT" target/linux/ramips/mt7621/config-6.6; then
        echo "CONFIG_NET_MEDIATEK_HNAT=m" >> target/linux/ramips/mt7621/config-6.6
    fi
else
    echo "警告: MT7621 内核配置文件不存在"
fi

# 6. 添加内核模块定义
echo "添加 HNAT 内核模块定义..."
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
fi

echo "HNAT 补丁应用完成！"
