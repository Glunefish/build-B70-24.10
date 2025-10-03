#!/bin/bash
echo "开始应用 HNAT 支持补丁..."

# 创建必要的目录结构
mkdir -p target/linux/ramips/files/drivers/net/ethernet/mediatek/

# 1. 复制驱动源码从 mediatek 到 ramips
echo "复制 HNAT 驱动源码..."
cp -r target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat target/linux/ramips/files/drivers/net/ethernet/mediatek/

# 2. 添加设备树节点到 mt7621.dtsi
echo "添加 HNAT 设备树节点..."
cat >> target/linux/ramips/dts/mt7621.dtsi << 'EOF'

	hnat: hnat@1e100000 {
		compatible = "mediatek,mtk-hnat_v1";
		reg = <0x1e100000 0x3000>;
		status = "disabled";
	};
EOF

# 3. 在 HC5962 设备树中启用 HNAT
echo "在 HC5962 设备树中启用 HNAT..."
cat >> target/linux/ramips/dts/mt7621_hiwifi_hc5962.dts << 'EOF'

&hnat {
	status = "okay";
};
EOF

# 4. 添加内核配置
echo "添加 HNAT 内核配置..."
echo "CONFIG_NET_MEDIATEK_HNAT=m" >> target/linux/ramips/mt7621/config-6.6

# 5. 添加内核模块定义
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
