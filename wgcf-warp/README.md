# Wgcf WARP

使用基于WireGuard的Wgcf非官方CloudFlare WARP客户端，实现VPS内的代理上网

## 使用方法

请谨慎选择脚本，否则VPS失联不关我的事。

### 原生 IPv4 VPS + IPv6 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/warp46.sh && bash warp46.sh
```

### 原生 IPv4 VPS + 双栈 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/warp4d.sh && bash warp4d.sh
```

### 原生 IPv6 VPS + IPv4 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/warp64.sh && bash warp64.sh
```

### 原生 IPv6 VPS + 双栈 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/warp6d.sh && bash warp6d.sh
```

### 原生双栈 VPS + 双栈 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/warpd.sh && bash warpd.sh
```

### 开启 / 关闭 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/switchwarp.sh && bash switchwarp.sh
```

### 卸载 WARP

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/uninstall.sh && bash uninstall.sh
```

### 刷Netfilx IP (IPv4)

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/netfilx4.sh && bash netfilx4.sh
```

### 刷Netfilx IP (IPv6)

```shell
wget -N https://raw.githubusercontents.com/blandarich/AJ-WARP/master/wgcf-warp/netfilx6.sh && bash netfilx6.sh
```
