rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages

# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall-luci


git clone https://github.com/lwb1978/openwrt-gecoosac ./package/openwrt-gecoosac
git clone https://github.com/rufengsuixing/luci-app-adguardhome ./package/luci-app-adguardhome
git clone https://github.com/zzsj0928/luci-app-pushbot ./package/luci-app-pushbot
git clone https://github.com/sirpdboy/luci-app-lucky ./package/luci-app-lucky
