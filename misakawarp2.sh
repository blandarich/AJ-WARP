#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')") 

for i in "${CMD[@]}"; do
    SYS="$i" 
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

archAffix(){
    case "$(uname -m)" in
        i686 | i386 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv5tel ) echo 'armv5' ;;
        armv6l ) echo 'armv6' ;;
        armv7 | armv7l ) echo 'armv7' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构！" && exit 1 ;;
    esac
}

check_status(){
    yellow "正在检查VPS系统状态..."
    if [[ -z $(type -P curl) ]]; then
        yellow "检测curl未安装，正在安装中..."
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} curl
    fi

    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)

    if [[ $IPv4Status =~ "on"|"plus" ]] || [[ $IPv6Status =~ "on"|"plus" ]]; then
        # 关闭Wgcf-WARP，以防识别有误
        wg-quick down wgcf >/dev/null 2>&1
        v66=`curl -s6m8 https://ip.gs -k`
        v44=`curl -s4m8 https://ip.gs -k`
        wg-quick up wgcf >/dev/null 2>&1
    else
        v66=`curl -s6m8 https://ip.gs -k`
        v44=`curl -s4m8 https://ip.gs -k`
    fi

    if [[ $IPv4Status == "off" ]]; then
        w4="${RED}未启用WARP${PLAIN}"
    fi
    if [[ $IPv6Status == "off" ]]; then
        w6="${RED}未启用WARP${PLAIN}"
    fi
    if [[ $IPv4Status == "on" ]]; then
        w4="${YELLOW}WARP 免费账户${PLAIN}"
    fi
    if [[ $IPv6Status == "on" ]]; then
        w6="${YELLOW}WARP 免费账户${PLAIN}"
    fi
    if [[ $IPv4Status == "plus" ]]; then
        w4="${GREEN}WARP+ / Teams${PLAIN}"
    fi
    if [[ $IPv6Status == "plus" ]]; then
        w6="${GREEN}WARP+ / Teams${PLAIN}"
    fi

    # VPSIP变量说明：0为纯IPv6 VPS、1为纯IPv4 VPS、2为原生双栈VPS
    if [[ -n $v66 ]] && [[ -z $v44 ]]; then
        VPSIP=0
    elif [[ -z $v66 ]] && [[ -n $v44 ]]; then
        VPSIP=1
    elif [[ -n $v66 ]] && [[ -n $v44 ]]; then
        VPSIP=2
    fi

    v4=$(curl -s4m8 https://ip.gs -k)
    v6=$(curl -s6m8 https://ip.gs -k)
    c4=$(curl -s4m8 https://ip.gs/country -k)
    c6=$(curl -s6m8 https://ip.gs/country -k)
    s5p=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    w5p=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
    if [[ -n $s5p ]]; then
        s5s=$(curl -sx socks5h://localhost:$s5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        s5i=$(curl -sx socks5h://localhost:$s5p https://ip.gs -k --connect-timeout 8)
        s5c=$(curl -sx socks5h://localhost:$s5p https://ip.gs/country -k --connect-timeout 8)
    fi
    if [[ -n $w5p ]]; then
        w5s=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        w5i=$(curl -sx socks5h://localhost:$w5p https://ip.gs -k --connect-timeout 8)
        w5c=$(curl -sx socks5h://localhost:$w5p https://ip.gs/country -k --connect-timeout 8)
    fi

    if [[ -z $s5s ]] || [[ $s5s == "off" ]]; then
        s5="${RED}未启动${PLAIN}"
    fi
    if [[ -z $w5s ]] || [[ $w5s == "off" ]]; then
        w5="${RED}未启动${PLAIN}"
    fi
    if [[ $s5s == "on" ]]; then
        s5="${YELLOW}WARP 免费账户${PLAIN}"
    fi
    if [[ $w5s == "on" ]]; then
        w5="${YELLOW}WARP 免费账户${PLAIN}"
    fi
    if [[ $s5s == "plus" ]]; then
        s5="${GREEN}WARP+ / Teams${PLAIN}"
    fi
    if [[ $w5s == "plus" ]]; then
        w5="${GREEN}WARP+ / Teams${PLAIN}"
    fi
}

check_tun(){
    vpsvirt=$(systemd-detect-virt)
    main=`uname  -r | awk -F . '{print $1}'`
    minor=`uname -r | awk -F . '{print $2}'`
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
    if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then
        if [[ $vpsvirt == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到未开启TUN模块，请到VPS厂商的控制面板处开启" 
                exit 1
            else
                yellow "检测到您的VPS为LXC架构，且支持内核级别的Wireguard，继续安装"
            fi
        elif [[ $vpsvirt == "openvz" ]]; then
            wget -N --no-check-certificate https://gitlab.com/misaka-blog/tun-script/-/raw/master/tun.sh && bash tun.sh
        else
            red "检测到未开启TUN模块，请到VPS厂商的控制面板处开启" 
            exit 1
        fi
    fi
}

check_best_mtu(){
    yellow "正在设置MTU最佳值，请稍等..."
    v66=`curl -s6m8 https://ip.gs -k`
    v44=`curl -s4m8 https://ip.gs -k`
    MTUy=1500
    MTUc=10
    if [[ -n ${v66} && -z ${v44} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    MTU=$((${MTUy} - 80))
    green "MTU 最佳值=$MTU 已设置完毕"
}

docker_warn(){
    if [[ -n $(type -P docker) ]]; then
        yellow "检测到Docker已安装，如继续安装Wgcf-WARP，则有可能会影响你的Docker容器"
        read -rp "是否继续安装？[Y/N]：" yesno
        if [[ $yesno =~ "Y"|"y" ]]; then
            green "继续安装Wgcf-WARP"
        else
            red "取消安装Wgcf-WARP"
            exit 1
        fi
    fi
}

wgcf44(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -4 rule delete from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i '/\:\:\/0/d' wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ "on"|"plus" ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
}

wgcf46(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i '/0\.\0\/0/d' wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ "on"|"plus" ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

wgcf4d(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -4 rule delete from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARP4Status =~ on|plus ]] && [[ $WgcfWARP6Status =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

wgcf64(){
    sed -i 's/1.1.1.1/2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' wgcf-profile.conf
    sed -i '/\:\:\/0/d' wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1
    
    WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
}

wgcf66(){
    sed -i 's/1.1.1.1/2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -6 rule delete from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i '/0\.\0\/0/d' wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

wgcf6d(){
    sed -i 's/1.1.1.1/2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -6 rule delete from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARP4Status =~ on|plus ]] && [[ $WgcfWARP6Status =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

wgcfd4(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -4 rule delete from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i '/\:\:\/0/d' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
}

wgcfd6(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -6 rule delete from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i '/0\.\0\/0/d' wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARPStatus =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARPStatus=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

wgcfd(){
    sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' wgcf-profile.conf
    sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "8 s/^/PostDown = ip -4 rule delete from $(ip route get 114.114.114.114 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "9 s/^/PostUp = ip -6 rule add from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    sed -i "10 s/^/PostDown = ip -6 rule delete from $(ip route get 2400:3200::1 | grep -oP 'src \K\S+') lookup main\n/" wgcf-profile.conf
    
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi
    mv -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml
    
    yellow "正在启动 Wgcf-WARP"
    wg-quick up wgcf >/dev/null 2>&1

    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    retry_time=1
    until [[ $WgcfWARP4Status =~ on|plus ]] && [[ $WgcfWARP6Status =~ on|plus ]]; do
        red "无法启动Wgcf-WARP，正在尝试重启，重试次数：$retry_time"
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        sleep 8
        retry_time=$((${retry_time} + 1))
        if [[ $retry_time == 6 ]]; then
            uninstall_wgcf
            echo ""
            red "由于Wgcf-WARP启动重试次数过多，已自动卸载Wgcf-WARP"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为系统官方源！"
            yellow "2. 部分VPS系统过于精简，相关依赖需自行安装后再重试"
            yellow "3. 检查 https://www.cloudflarestatus.com/， 查询VPS就近区域。如处于黄色的【Re-routed】状态则不可使用Wgcf-WARP"
            yellow "4. 脚本可能跟不上时代，建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            exit 1
        fi
    done
    systemctl enable wg-quick@wgcf >/dev/null 2>&1

    WgcfIPv4=$(curl -s4m8 https://ip.gs -k)
    WgcfIPv6=$(curl -s6m8 https://ip.gs -k)
    green "Wgcf-WARP 已启动成功"
    yellow "Wgcf-WARP的IPv4 IP为：$WgcfIPv4"
    yellow "Wgcf-WARP的IPv6 IP为：$WgcfIPv6"
}

install_wgcf(){
    main=`uname  -r | awk -F . '{print $1}'`
    minor=`uname -r | awk -F . '{print $2}'`
    vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${vsid} =~ 7|8 ]] && yellow "当前系统版本：CentOS $vsid \nWgcf-WARP模式仅支持CentOS 7-8系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${vsid} =~ 10|11 ]] && yellow "当前系统版本：Debian $vsid \nWgcf-WARP模式仅支持Debian 10-11系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${vsid} =~ 16|18|20|22 ]] && yellow "当前系统版本：Ubuntu $vsid \nWgcf-WARP模式仅支持Ubuntu 16.04/18.04/20.04/22.04系统" && exit 1

    if [[ $c4 == "Hong Kong" || $c6 == "Hong Kong" ]]; then
        red "检测到地区为 Hong Kong 的VPS！"
        yellow "由于 CloudFlare 对 Hong Kong 屏蔽了 Wgcf，因此无法使用 Wgcf-WARP。请使用其他地区的VPS"
        exit 1
    fi

    check_tun
    docker_warn
    
    if [[ $SYSTEM == "CentOS" ]]; then        
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools wireguard-tools iptables htop screen iputils
        if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then 
            if [[ $vpsvirt =~ "kvm"|"xen"|"microsoft"|"vmware"|"qemu" ]]; then
                vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
                curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-$vsid/jdoss-wireguard-epel-$vsid.repo
                ${PACKAGE_INSTALL[int]} wireguard-dkms
            fi
        fi
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release htop inetutils-ping
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv screen dnsutils wireguard-tools iptables
        if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
            if [[ $vpsvirt =~ "kvm"|"xen"|"microsoft"|"vmware"|"qemu" ]]; then
                ${PACKAGE_INSTALL[int]} --no-install-recommends linux-headers-$(uname -r)
                ${PACKAGE_INSTALL[int]} --no-install-recommends wireguard-dkms
            fi
        fi
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop inetutils-ping
        if [[ $vsid =~ 16 ]]; then
            add-apt-repository ppa:wireguard/wireguard
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils screen wireguard-tools iptables
        if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
            if [[ $vpsvirt =~ "kvm"|"xen"|"microsoft"|"vmware"|"qemu" ]]; then
                ${PACKAGE_INSTALL[int]} --no-install-recommends wireguard-dkms
            fi
        fi
    fi

    if [[ $vpsvirt =~ lxc|openvz ]]; then
        if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
            wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/files/wireguard-go -O /usr/bin/wireguard-go
            chmod +x /usr/bin/wireguard-go
        fi
    fi
    if [[ $vpsvirt == zvm ]]; then
        wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/files/wireguard-go-s390x -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/files/wgcf_latest_linux_$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf

    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        wgcfFile=1
    fi
    if [[ -f /root/wgcf-account.toml ]]; then
        wgcfFile=1
    fi

    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP申请账号，如提示429 Too Many Requests错误请耐心等待即可"
        yes | wgcf register
        sleep 5
    done
    chmod +x wgcf-account.toml

    if [[ ! $wgcfFile == 1 ]]; then
        yellow "使用WARP免费版账户请按回车跳过 \n启用WARP+账户，请复制WARP+的许可证密钥(26个字符)后回车"
        read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            sed -i "s/license_key.*/license_key = \"$WPPlusKey\"/g" wgcf-account.toml
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名：" WPPlusName
            green "注册WARP+账户中，如下方显示：400 Bad Request，则使用WARP免费版账户" 
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
        fi
    fi
    
    wgcf generate
    chmod +x wgcf-profile.conf

    check_best_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf

    if [[ $VPSIP == 0 ]]; then
        if [[ $wgcfmode == 0 ]]; then
            wgcf64
        fi

        if [[ $wgcfmode == 1 ]]; then
            wgcf66
        fi
        
        if [[ $wgcfmode == 2 ]]; then
            wgcf6d
        fi
    elif [[ $VPSIP == 1 ]]; then
        if [[ $wgcfmode == 0 ]]; then
            wgcf44
        fi

        if [[ $wgcfmode == 1 ]]; then
            wgcf46
        fi

        if [[ $wgcfmode == 2 ]]; then
            wgcf4d
        fi
    elif [[ $VPSIP == 2 ]]; then
        if [[ $wgcfmode == 0 ]]; then
            wgcfd4
        fi

        if [[ $wgcfmode == 1 ]]; then
            wgcfd6
        fi

        if [[ $wgcfmode == 2 ]]; then
            wgcfd
        fi
    fi
}

wgcf_switch(){
    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)

    if [[ $WgcfWARP4Status =~ on|plus ]] || [[ $WgcfWARP6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        green "Wgcf-WARP关闭成功！"
        exit 1
    fi

    if [[ $WgcfWARP4Status == off ]] || [[ $WgcfWARP6Status == off ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf >/dev/null 2>&1
        green "Wgcf-WARP启动成功！"
        exit 1
    fi
}

uninstall_wgcf(){
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null
    ${PACKAGE_UNINSTALL[int]} wireguard-tools wireguard-dkms
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-account.toml
    fi
    rm -f /etc/wireguard/wgcf.conf
    rm -f /usr/bin/wireguard-go
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi
    green "Wgcf-WARP 已彻底卸载成功！"
}

install_warpcli(){
    main=`uname  -r | awk -F . '{print $1}'`
    minor=`uname -r | awk -F . '{print $2}'`
    vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${vsid} =~ 8 ]] && yellow "当前系统版本：CentOS $vsid \nWARP-Cli代理模式仅支持CentOS 8系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${vsid} =~ 9|10|11 ]] && yellow "当前系统版本：Debian $vsid \nWARP-Cli代理模式仅支持Debian 9-11系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${vsid} =~ 16|18|20 ]] && yellow "当前系统版本：Ubuntu $vsid \nWARP-Cli代理模式仅支持Ubuntu 16.04/18.04/20.04系统" && exit 1

    check_tun

    if [[ $(archAffix) != "amd64" ]]; then
        red "WARP-Cli暂时不支持目前VPS的CPU架构，请使用CPU架构为amd64的VPS"
        exit 1
    fi
    
    v66=`curl -s6m8 https://ip.gs -k`
    v44=`curl -s4m8 https://ip.gs -k`
    WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    
    if [[ -n ${v66} && -z ${v44} ]]; then
        red "WARP-Cli 代理模式不支持纯IPv6的VPS！！"
        exit 1
    elif [[ $WgcfWARP4Status =~ on|plus ]]; then
        red "检测到IPv4出口已被Wgcf-WARP接管，无法启用WARP-Cli代理模式！"
        exit 1
    fi

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools htop iputils screen
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi

    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop inetutils-ping screen
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release htop inetutils-ping screen
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi

    warp-cli --accept-tos register >/dev/null 2>&1
    yellow "使用WARP免费版账户请按回车跳过 \n启用WARP+账户，请复制WARP+的许可证密钥(26个字符)后回车"
    read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
    if [[ -n $WPPlusKey ]]; then
        warp-cli --accept-tos set-license "$WPPlusKey" >/dev/null 2>&1 && sleep 1
        if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
            green "WARP+账户启用成功"
        else
            red "WARP+账户启用失败，即将使用WARP免费版账户"
        fi
    fi
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1

    read -rp "请输入WARP-Cli使用的代理端口（默认40000）：" WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=40000
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1

    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    sleep 5
    socks5IP=$(curl -sx socks5h://localhost:$WARPCliPort ip.gs -k --connect-timeout 8)
    green "WARP-Cli代理模式已启动成功！"
    yellow "本地Socks5代理为： 127.0.0.1:$WARPCliPort"
    yellow "WARP-Cli代理模式的IP为：$socks5IP"
}

change_warpcli_port() {
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
    fi
    read -rp "请输入WARP-Cli使用的代理端口（默认40000）：" WARPCliPort
    [[ -z $WARPCliPort ]] && WARPCliPort=40000
    warp-cli --accept-tos set-proxy-port "$WARPCliPort" >/dev/null 2>&1
    yellow "正在启动Warp-Cli代理模式"
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    socks5IP=$(curl -sx socks5h://localhost:$WARPCliPort ip.gs -k --connect-timeout 8)
    green "WARP-Cli代理模式已启动成功并成功修改代理端口！"
    yellow "本地Socks5代理为： 127.0.0.1:$WARPCliPort"
    yellow "WARP-Cli代理模式的IP为：$socks5IP"
}

warpcli_switch(){
    if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        green "WARP-Cli代理模式关闭成功！"
        rm -f switch.sh
        exit 1
    fi
    if [[ $(warp-cli --accept-tos status) =~ Disconnected ]]; then
        yellow "正在启动Warp-Cli代理模式"
        warp-cli --accept-tos connect >/dev/null 2>&1
        until [[ $(warp-cli --accept-tos status) =~ Connected ]]; do
            red "启动Warp-Cli代理模式失败，正在尝试重启"
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            warp-cli --accept-tos connect >/dev/null 2>&1
            sleep 5
        done
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        WARPCliPort=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
        green "WARP-Cli代理模式启动成功！"
        yellow "本地Socks5代理为：127.0.0.1:$WARPCliPort"
        rm -f switch.sh
        exit 1
    fi
}

uninstall_warpcli(){
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp
    systemctl disable --now warp-svc >/dev/null 2>&1
    green "WARP-Cli代理模式已彻底卸载成功！"
}

install_wireproxy(){
    if [[ $c4 == "Hong Kong" || $c6 == "Hong Kong" ]]; then
        red "检测到地区为 Hong Kong 的VPS！"
        yellow "由于 CloudFlare 对 Hong Kong 屏蔽了 Wgcf，因此无法使用 WireProxy-WARP 代理模式。请使用其他地区的VPS"
        exit 1
    fi

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget htop iputils screen
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget htop inetutils-ping screen
    fi

    wget -N https://gitlab.com/misaka-blog/warp-script/-/raw/master/files/wireproxy-$(archAffix) -O /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy

    wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/files/wgcf_latest_linux_$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf

    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        wgcfFile=1
    fi
    if [[ -f /root/wgcf-account.toml ]]; then
        wgcfFile=1
    fi

    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP申请账号，如提示429 Too Many Requests错误请耐心等待即可"
        yes | wgcf register
        sleep 5
    done
    chmod +x wgcf-account.toml

    if [[ ! $wgcfFile == 1 ]]; then
        yellow "使用WARP免费版账户请按回车跳过 \n启用WARP+账户，请复制WARP+的许可证密钥(26个字符)后回车"
        read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            sed -i "s/license_key.*/license_key = \"$WPPlusKey\"/g" wgcf-account.toml
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名：" WPPlusName
            green "注册WARP+账户中，如下方显示：400 Bad Request，则使用WARP免费版账户" 
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi
        fi
    fi
    
    wgcf generate
    chmod +x wgcf-profile.conf

    IPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    IPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)

    if [[ $IPv4Status =~ "on"|"plus" ]] || [[ $IPv6Status =~ "on"|"plus" ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        check_best_mtu
        wg-quick up wgcf >/dev/null 2>&1
    else
        check_best_mtu
    fi

    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
    
    read -rp "请输入将要设置的Socks5代理端口（默认40000）：" WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=40000
    WgcfPrivateKey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
    WgcfPublicKey=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    WgcfV4Endpoint="162.159.193.10:2408"
    WgcfV6Endpoint="[2606:4700:d0::a29f:c001]:2408"

    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
        chmod -R 777 /etc/wireguard
    fi

    if [[ $VPSIP == 0 ]]; then
        WireproxyEndpoint=$WgcfV6Endpoint
    elif [[ $VPSIP == 1 ]]; then
        WireproxyEndpoint=$WgcfV4Endpoint
    elif [[ $VPSIP == 2 ]]; then
        WireproxyEndpoint=$WgcfV4Endpoint
    fi
    
    cat <<EOF > /etc/wireguard/proxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = $MTU
PrivateKey = $WgcfPrivateKey
DNS = 1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844

[Peer]
PublicKey = $WgcfPublicKey
Endpoint = $WireproxyEndpoint

[Socks5]
BindAddress = 127.0.0.1:$WireProxyPort
EOF

    cat <<'TEXT' > /etc/systemd/system/wireproxy-warp.service
[Unit]
Description=CloudFlare WARP Socks5 mode based for WireProxy, script by owo.misaka.rest
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/bin/wireproxy -c /etc/wireguard/proxy.conf
Restart=always
TEXT

    rm -f wgcf-profile.conf
    mv wgcf-account.toml /etc/wireguard/wgcf-account.toml

    yellow "正在启动WireProxy-WARP代理模式"
    systemctl start wireproxy-warp
    socks5Status=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    until [[ $socks5Status =~ on|plus ]]; do
        red "启动WireProxy-WARP代理模式失败，正在尝试重启"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        socks5Status=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 8
    done
    sleep 5
    systemctl enable wireproxy-warp >/dev/null 2>&1
    socks5IP=$(curl -sx socks5h://localhost:$WireProxyPort https://ip.gs -k --connect-timeout 8)
    green "WireProxy-WARP代理模式已启动成功！"
    yellow "本地Socks5代理为： 127.0.0.1:$WireProxyPort"
    yellow "WireProxy-WARP代理模式的IP为：$socks5IP"
}

change_wireproxy_port(){
    systemctl stop wireproxy-warp
    read -rp "请输入WARP Cli使用的代理端口 (默认40000): " WireProxyPort
    [[ -z $WireProxyPort ]] && WireProxyPort=40000
    CurrentPort=$(grep BindAddress /etc/wireguard/proxy.conf)
    sed -i "s/$CurrentPort/BindAddress = 127.0.0.1:$WireProxyPort/g" /etc/wireguard/proxy.conf
    yellow "正在启动WireProxy-WARP代理模式"
    systemctl start wireproxy-warp
    socks5Status=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    until [[ $socks5Status =~ on|plus ]]; do
        red "启动WireProxy-WARP代理模式失败，正在尝试重启"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        socks5Status=$(curl -sx socks5h://localhost:$WireProxyPort https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 8
    done
    systemctl enable wireproxy-warp
    green "WireProxy-WARP代理模式已启动成功！"
    yellow "本地Socks5代理为: 127.0.0.1:$WireProxyPort"
}

wireproxy_switch(){
    w5p=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")
    w5s=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    if [[ $w5s =~ "on"|"plus" ]]; then
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
    fi
    if [[ $w5s =~ "off" ]] || [[ -z $w5s ]]; then
        systemctl start wireproxy-warp
        systemctl enable wireproxy-warp
    fi
}

uninstall_wireproxy(){
    systemctl stop wireproxy-warp
    systemctl disable wireproxy-warp
    rm -f /etc/systemd/system/wireproxy-warp.service /usr/local/bin/wireproxy /etc/wireguard/proxy.conf
    if [[ ! -f /etc/wireguard/wgcf.conf ]]; then
        rm -f /usr/local/bin/wgcf /etc/wireguard/wgcf-account.toml
    fi
    green "WireProxy-WARP代理模式已彻底卸载成功!"
}

warpup(){
    yellow "获取CloudFlare WARP账号信息方法："
    green "电脑：下载并安装CloudFlare WARP→设置→偏好设置→复制设备ID到脚本中"
    green "手机：下载并安装1.1.1.1 APP→菜单→高级→诊断→复制设备ID到脚本中"
    echo ""
    yellow "请按照下面指示，输入您的CloudFlare WARP账号信息："
    read -rp "请输入您的WARP设备ID (36位字符): " WarpDeviceID
    read -rp "请输入你期望刷到的流量 (单位: GB): " WarpFlowLimit
    echo -e "你期望刷到的流量为：$WarpFlowLimit GB"
    for ((i = 0; i < ${WarpFlowLimit}; i++)); do
        if [[ $i == 0 ]]; then
            sleep_try=30
            sleep_min=20
            sleep_max=600
        fi

        install_id=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
        curl -X POST -m 10 -sA "okhttp/3.12.1" -H 'content-type: application/json' -H 'Host: api.cloudflareclient.com' --data "{\"key\": \"$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 43)=\",\"install_id\": \"$install_id\",\"fcm_token\": \"APA91b$install_id$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)\",\"referrer\": \"$WarpDeviceID\",\"warp_enabled\": false,\"tos\": \"$(date -u +%FT%T.$(tr -dc '0-9' </dev/urandom | head -c 3)Z)\",\"type\": \"Android\",\"locale\": \"en_US\"}"  --url "https://api.cloudflareclient.com/v0a$(shuf -i 100-999 -n 1)/reg" | grep -qE "referral_count\":1" && status=0 || status=1
        
        # cloudflare限制了请求频率,目前测试大概在20秒,失败时因延长sleep时间
        [[ $sleep_try > $sleep_max ]] && sleep_try=300
        [[ $sleep_try == $sleep_min ]] && sleep_try=$((sleep_try+1))

        if [[ $status == 0 ]]; then
            sleep_try=$((sleep_try-1))
            sleep $sleep_try
            rit[i]=$i
            echo -n $i-o-
            continue
        fi

        if [[ $status == 1 ]]; then
            sleep_try=$((sleep_try+2))
            sleep $sleep_try
            bad[i]=$i
            echo -n $i-x-
            continue
        fi
    done
    echo ""
    echo -e "此次运行共成功获取warp+流量 ${GREEN} ${#rit[*]} ${PLAIN} GB"
}

warpsw1(){
    yellow "请选择切换的账户类型"
    green "1. WARP 免费账户"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请选择账户类型 [1-3]: " accountInput
    if [[ $accountInput == 1 ]]; then
        wg-quick down wgcf >/dev/null 2>&1

        cd /etc/wireguard
        rm -f wgcf-account.toml

        until [[ -a wgcf-account.toml ]]; do
            yes | wgcf register
            sleep 5
        done
        chmod +x wgcf-account.toml
        
        wgcf generate
        chmod +x wgcf-profile.conf

        warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
        warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
        sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
        sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/wgcf.conf;
        rm -f wgcf-profile.conf

        wg-quick up wgcf >/dev/null 2>&1
        yellow "正在检查WARP 免费账户连通性，请稍等..."
        WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
        if [[ $WgcfWARP4Status == "on" || $WgcfWARP6Status == "on" ]]; then
            green "Wgcf-WARP 账户类型切换为 WARP 免费账户 成功！"
        else
            green "有可能CF出了bug，已经自动给你白嫖了WARP+账户！"
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        cd /etc/wireguard
        if [[ ! -f wgcf-account.toml ]]; then
            until [[ -a wgcf-account.toml ]]; do
                yes | wgcf register
                sleep 5
            done
        fi
        chmod +x wgcf-account.toml

        read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名：" WPPlusName
            green "注册WARP+账户中，如下方显示：400 Bad Request，则使用WARP免费版账户" 
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi

            wgcf generate
            chmod +x wgcf-profile.conf

            wg-quick down wgcf >/dev/null 2>&1

            warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
            warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
            sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
            sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/wgcf.conf;
            rm -f wgcf-profile.conf

            wg-quick up wgcf >/dev/null 2>&1
            yellow "正在检查WARP+账户连通性，请稍等..."
            WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            if [[ $WgcfWARP4Status == "plus" || $WgcfWARP6Status == "plus" ]]; then
                green "Wgcf-WARP 账户类型切换为 WARP+ 成功！"
            else
                red "WARP+ 配置有误，已自动降级至WARP 免费账户！"
            fi
        else
            red "未输入WARP账户许可证密钥，无法升级！"
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        read -rp "请输入WARP Teams配置文件中的PrivateKey：" wpteamprivatekey
        read -rp "请输入WARP Teams配置文件中的IPv6地址：" wpteamv6address
        yellow "请确认WARP Teams信息是否正确："
        green "PrivateKey: $wpteamprivatekey"
        green "IPv6 地址: $wpteamv6address"
        read -rp "确认以上信息正确请输入y，其他按键退出升级过程：" wpteamconfirm
        if [[ $wpteamconfirm =~ "y"|"Y" ]]; then
            wg-quick down wgcf >/dev/null 2>&1

            sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/wgcf.conf;
            sed -i "s#Address.*128#Address = $wpteamv6address/128#g" /etc/wireguard/wgcf.conf;

            wg-quick up wgcf >/dev/null 2>&1
            yellow "正在检查WARP Teams账户连通性，请稍等..."
            WgcfWARP4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WgcfWARP6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            if [[ $WgcfWARP4Status == "plus" || $WgcfWARP6Status == "plus" ]]; then
                green "Wgcf-WARP 账户类型切换为 WARP Teams 成功！"
            else
                wg-quick down wgcf >/dev/null 2>&1

                wgcf generate
                chmod +x wgcf-profile.conf

                warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
                warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
                sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/wgcf.conf;
                rm -f wgcf-profile.conf

                wg-quick up wgcf >/dev/null 2>&1
                red "WARP Teams配置有误，已自动降级至WARP 免费账户 / WARP+！"
            fi
        else
            red "已退出WARP Teams账号升级过程！"
        fi
    fi
}

warpsw2(){
    warp-cli --accept-tos register >/dev/null 2>&1
    read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
    if [[ -n $WPPlusKey ]]; then
        warp-cli --accept-tos set-license "$WPPlusKey" >/dev/null 2>&1 && sleep 1
        if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
            green "WARP-Cli 账户类型切换为 WARP+ 成功！"
        else
            red "WARP+账户启用失败，即将使用WARP免费版账户"
        fi
    fi
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
}

warpsw3(){
    yellow "请选择切换的账户类型"
    green "1. WARP 免费账户"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请选择账户类型 [1-3]: " accountInput
    if [[ $accountInput == 1 ]]; then
        systemctl stop wireproxy-warp

        cd /etc/wireguard
        rm -f wgcf-account.toml

        until [[ -a wgcf-account.toml ]]; do
            yes | wgcf register
            sleep 5
        done
        chmod +x wgcf-account.toml
        
        wgcf generate
        chmod +x wgcf-profile.conf

        warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
        warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/proxy.conf;
        sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/proxy.conf;
        rm -f wgcf-profile.conf

        systemctl start wireproxy-warp
        yellow "正在检查WARP 免费账户连通性，请稍等..."
        WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $WireProxyStatus == "on" ]]; then
            green "WireProxy-WARP代理模式 账户类型切换为 WARP 免费账户 成功！"
        else
            green "有可能CF出了bug，已经自动给你白嫖了WARP+账户！"
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        cd /etc/wireguard
        if [[ ! -f wgcf-account.toml ]]; then
            until [[ -a wgcf-account.toml ]]; do
                yes | wgcf register
                sleep 5
            done
        fi
        chmod +x wgcf-account.toml

        read -rp "输入WARP账户许可证密钥 (26个字符):" WPPlusKey
        if [[ -n $WPPlusKey ]]; then
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名：" WPPlusName
            green "注册WARP+账户中，如下方显示：400 Bad Request，则使用WARP免费版账户" 
            if [[ -n $WPPlusName ]]; then
                wgcf update --name $(echo $WPPlusName | sed s/[[:space:]]/_/g)
            else
                wgcf update
            fi

            wgcf generate
            chmod +x wgcf-profile.conf

            systemctl stop wireproxy-warp

            warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
            warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
            sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/proxy.conf;
            sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/proxy.conf;
            rm -f wgcf-profile.conf

            systemctl start wireproxy-warp
            yellow "正在检查WARP+账户连通性，请稍等..."
            WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $WireProxyStatus == "plus" ]]; then
                green "WireProxy-WARP代理模式 账户类型切换为 WARP+ 成功！"
            else
                red "WARP+ 配置有误，已自动降级至WARP 免费账户！"
            fi
        else
            red "未输入WARP账户许可证密钥，无法升级！"
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        read -rp "请输入WARP Teams配置文件中的PrivateKey：" wpteamprivatekey
        read -rp "请输入WARP Teams配置文件中的IPv6地址：" wpteamv6address
        yellow "请确认WARP Teams信息是否正确："
        green "PrivateKey: $wpteamprivatekey"
        green "IPv6 地址: $wpteamv6address"
        read -rp "确认以上信息正确请输入y，其他按键退出升级过程：" wpteamconfirm
        if [[ $wpteamconfirm =~ "y"|"Y" ]]; then
            systemctl stop wireproxy-warp

            sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/proxy.conf;
            sed -i "s#Address.*128#Address = $wpteamv6address/128#g" /etc/wireguard/proxy.conf;

            systemctl start wireproxy-warp
            yellow "正在检查WARP Teams账户连通性，请稍等..."
            WireProxyStatus=$(curl -sx socks5h://localhost:$w5p https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $WireProxyStatus == "plus" ]]; then
                green "WireProxy-WARP代理模式 账户类型切换为 WARP Teams 成功！"
            else
                systemctl stop wireproxy-warp

                wgcf generate
                chmod +x wgcf-profile.conf

                warpPrivatekey=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")
                warpIPv6Address=$(grep "Address = fd01" wgcf-profile.conf | sed "s/Address = //g")
                sed -i "s#PrivateKey.*#PrivateKey = $warpPrivatekey#g" /etc/wireguard/proxy.conf;
                sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/proxy.conf;
                rm -f wgcf-profile.conf

                systemctl start wireproxy-warp
                red "WARP Teams配置有误，已自动降级至WARP 免费账户 / WARP+！"
            fi
        else
            red "已退出WARP Teams账号升级过程！"
        fi
    fi
}

warpsw(){
    yellow "请选择需要切换WARP账户的WARP客户端:"
    echo -e " ${GREEN}1.${PLAIN} Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} WARP-Cli 代理模式 ${RED}(目前仅支持升级WARP+账户)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} WireProxy-WARP 代理模式"
    read -rp "请选择客户端 [1-3]: " clientInput
    case "$clientInput" in
        1 ) warpsw1 ;;
        2 ) warpsw2 ;;
        3 ) warpsw3 ;;
        * ) exit 1 ;;
    esac
}

warpnf(){
    yellow "请选择需要刷NetFilx IP的WARP客户端:"
    green "1. Wgcf-WARP IPv4模式"
    green "2. Wgcf-WARP IPv6模式"
    green "3. WARP-Cli 代理模式"
    green "4. WireProxy-WARP 代理模式"
    read -rp "请选择客户端 [1-4]: " clientInput
    case "$clientInput" in
        1 ) wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/wgcf-warp/netfilx4.sh && bash netfilx4.sh ;;
        2 ) wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/wgcf-warp/netfilx6.sh && bash netfilx6.sh ;;
        3 ) wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/warp-cli/netfilxcli.sh && bash netfilxcli.sh ;;
        4 ) wget -N --no-check-certificate https://gitlab.com/misaka-blog/warp-script/-/raw/master/wireproxy-warp/netfilx-wireproxy.sh && bash netfilx-wireproxy.sh ;;
    esac
}

menu(){
    check_status
    if [[ $VPSIP == 0 ]]; then
        menu0
    elif [[ $VPSIP == 1 ]]; then
        menu1
    elif [[ $VPSIP == 2 ]]; then
        menu2
    fi
}

menu0(){
    clear
    echo "#############################################################"
    echo -e "#                    ${RED} WARP  一键安装脚本${PLAIN}                    #"
    echo -e "# ${GREEN}作者${PLAIN}: Misaka No                                           #"
    echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/Misaka-blog                    #"
    echo -e "# ${GREEN}Bitbucket${PLAIN}: https://bitbucket.org/misakano7545             #"
    echo -e "# ${GREEN}GitLab${PLAIN}: https://gitlab.com/misaka-blog                    #"
    echo "#############################################################"
    echo -e ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv4 + 原生 IPv6)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 Wgcf-WARP 双栈模式 ${YELLOW}(WARP IPV4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 开启或关闭 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 安装 Wireproxy-WARP 代理模式 ${YELLOW}(Socks5 WARP)${PLAIN}"
    echo -e " ${GREEN}7.${PLAIN} 修改 Wireproxy-WARP 代理模式连接端口"
    echo -e " ${GREEN}8.${PLAIN} 开启或关闭 Wireproxy-WARP 代理模式"
    echo -e " ${GREEN}9.${PLAIN} ${RED}卸载 Wireproxy-WARP 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}10.${PLAIN} 获取 WARP+ 账户流量"
    echo -e " ${GREEN}11.${PLAIN} 切换 WARP 账户类型"
    echo -e " ${GREEN}12.${PLAIN} 获取解锁 Netflix 的 WARP IP"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    echo -e "VPS IP特征：${RED}纯IPv6的VPS${PLAIN}"
    if [[ -n $v4 ]]; then
        echo -e "IPv4 地址：$v4  地区：$c4  WARP状态：$w4"
    fi
    if [[ -n $v6 ]]; then
        echo -e "IPv6 地址：$v6  地区：$c6  WARP状态：$w6"
    fi
    if [[ -n $w5p ]]; then
        echo -e "WireProxy代理端口: 127.0.0.1:$w5p  WireProxy状态: $w5"
        if [[ -n $w5i ]]; then
            echo -e "WireProxy IP: $w5i  地区: $w5c"
        fi
    fi
    echo -e ""
    read -rp " 请输入选项 [0-12]:" menu0Input
    case "$menu0Input" in
        1 ) wgcfmode=0 && install_wgcf ;;
        2 ) wgcfmode=1 && install_wgcf ;;
        3 ) wgcfmode=2 && install_wgcf ;;
        4 ) wgcf_switch ;;
        5 ) uninstall_wgcf ;;
        6 ) install_wireproxy ;;
        7 ) change_wireproxy_port ;;
        8 ) wireproxy_switch ;;
        9 ) uninstall_wireproxy ;;
        10 ) warpup ;;
        11 ) warpsw ;;
        12 ) warpnf ;;
        * ) exit 1 ;;
    esac
}

menu1(){
    clear
    echo "#############################################################"
    echo -e "#                    ${RED} WARP  一键安装脚本${PLAIN}                    #"
    echo -e "# ${GREEN}作者${PLAIN}: Misaka No                                           #"
    echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/Misaka-blog                    #"
    echo -e "# ${GREEN}Bitbucket${PLAIN}: https://bitbucket.org/misakano7545             #"
    echo -e "# ${GREEN}GitLab${PLAIN}: https://gitlab.com/misaka-blog                    #"
    echo "#############################################################"
    echo -e " ${GREEN}1.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(原生 IPv4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 Wgcf-WARP 双栈模式 ${YELLOW}(WARP IPV4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 开启或关闭 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 安装 WARP-Cli 代理模式 ${YELLOW}(Socks5 WARP)${PLAIN} ${RED}(仅支持CPU架构为AMD64的VPS)${PLAIN}"
    echo -e " ${GREEN}7.${PLAIN} 修改 WARP-Cli 代理模式连接端口"
    echo -e " ${GREEN}8.${PLAIN} 开启或关闭 WARP-Cli 代理模式"
    echo -e " ${GREEN}9.${PLAIN} ${RED}卸载 WARP-Cli 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}10.${PLAIN} 安装 Wireproxy-WARP 代理模式 ${YELLOW}(Socks5 WARP)${PLAIN}"
    echo -e " ${GREEN}11.${PLAIN} 修改 Wireproxy-WARP 代理模式连接端口"
    echo -e " ${GREEN}12.${PLAIN} 开启或关闭 Wireproxy-WARP 代理模式"
    echo -e " ${GREEN}13.${PLAIN} ${RED}卸载 Wireproxy-WARP 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}14.${PLAIN} 获取 WARP+ 账户流量"
    echo -e " ${GREEN}15.${PLAIN} 切换 WARP 账户类型"
    echo -e " ${GREEN}16.${PLAIN} 获取解锁 Netflix 的 WARP IP"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    echo -e "VPS IP特征：${RED}纯IPv4的VPS${PLAIN}"
    if [[ -n $v4 ]]; then
        echo -e "IPv4 地址：$v4  地区：$c4  WARP状态：$w4"
    fi
    if [[ -n $v6 ]]; then
        echo -e "IPv6 地址：$v6  地区：$c6  WARP状态：$w6"
    fi
    if [[ -n $s5p ]]; then
        echo -e "WARP-Cli代理端口: 127.0.0.1:$s5p  WARP-Cli状态: $s5"
        if [[ -n $s5i ]]; then
            echo -e "WARP-Cli IP: $s5i  地区: $s5c"
        fi
    fi
    if [[ -n $w5p ]]; then
        echo -e "WireProxy代理端口: 127.0.0.1:$w5p  WireProxy状态: $w5"
        if [[ -n $w5i ]]; then
            echo -e "WireProxy IP: $w5i  地区: $w5c"
        fi
    fi
    echo -e ""
    read -rp " 请输入选项 [0-16]:" menu1Input
    case "$menu1Input" in
        1 ) wgcfmode=0 && install_wgcf ;;
        2 ) wgcfmode=1 && install_wgcf ;;
        3 ) wgcfmode=2 && install_wgcf ;;
        4 ) wgcf_switch ;;
        5 ) uninstall_wgcf ;;
        6 ) install_warpcli ;;
        7 ) change_warpcli_port ;;
        8 ) warpcli_switch ;;
        9 ) uninstall_warpcli ;;
        10 ) install_wireproxy ;;
        11 ) change_wireproxy_port ;;
        12 ) wireproxy_switch ;;
        13 ) uninstall_wireproxy ;;
        14 ) warpup ;;
        15 ) warpsw ;;
        16 ) warpnf ;;
        * ) exit 1 ;;
    esac
}

menu2(){
    clear
    echo "#############################################################"
    echo -e "#                    ${RED} WARP  一键安装脚本${PLAIN}                    #"
    echo -e "# ${GREEN}作者${PLAIN}: Misaka No                                           #"
    echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
    echo -e "# ${GREEN}GitHub${PLAIN}: https://github.com/Misaka-blog                    #"
    echo -e "# ${GREEN}Bitbucket${PLAIN}: https://bitbucket.org/misakano7545             #"
    echo -e "# ${GREEN}GitLab${PLAIN}: https://gitlab.com/misaka-blog                    #"
    echo "#############################################################"
    echo -e ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(WARP IPv4 + 原生 IPv6)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 Wgcf-WARP 单栈模式 ${YELLOW}(原生 IPv4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 Wgcf-WARP 双栈模式 ${YELLOW}(WARP IPV4 + WARP IPv6)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 开启或关闭 Wgcf-WARP"
    echo -e " ${GREEN}5.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 安装 WARP-Cli 代理模式 ${YELLOW}(Socks5 WARP)${PLAIN} ${RED}(仅支持CPU架构为AMD64的VPS)${PLAIN}"
    echo -e " ${GREEN}7.${PLAIN} 修改 WARP-Cli 代理模式连接端口"
    echo -e " ${GREEN}8.${PLAIN} 开启或关闭 WARP-Cli 代理模式"
    echo -e " ${GREEN}9.${PLAIN} ${RED}卸载 WARP-Cli 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}10.${PLAIN} 安装 Wireproxy-WARP 代理模式 ${YELLOW}(Socks5 WARP)${PLAIN}"
    echo -e " ${GREEN}11.${PLAIN} 修改 Wireproxy-WARP 代理模式连接端口"
    echo -e " ${GREEN}12.${PLAIN} 开启或关闭 Wireproxy-WARP 代理模式"
    echo -e " ${GREEN}13.${PLAIN} ${RED}卸载 Wireproxy-WARP 代理模式${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}14.${PLAIN} 获取 WARP+ 账户流量"
    echo -e " ${GREEN}15.${PLAIN} 切换 WARP 账户类型"
    echo -e " ${GREEN}16.${PLAIN} 获取解锁 Netflix 的 WARP IP"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo -e ""
    echo -e "VPS IP特征：${RED}原生IP双栈的VPS${PLAIN}"
    if [[ -n $v4 ]]; then
        echo -e "IPv4 地址：$v4  地区：$c4  WARP状态：$w4"
    fi
    if [[ -n $v6 ]]; then
        echo -e "IPv6 地址：$v6  地区：$c6  WARP状态：$w6"
    fi
    if [[ -n $s5p ]]; then
        echo -e "WARP-Cli代理端口: 127.0.0.1:$s5p  WARP-Cli状态: $s5"
        if [[ -n $s5i ]]; then
            echo -e "WARP-Cli IP: $s5i  地区: $s5c"
        fi
    fi
    if [[ -n $w5p ]]; then
        echo -e "WireProxy代理端口: 127.0.0.1:$w5p  WireProxy状态: $w5"
        if [[ -n $w5i ]]; then
            echo -e "WireProxy IP: $w5i  地区: $w5c"
        fi
    fi
    echo -e ""
    read -rp " 请输入选项 [0-16]:" menu2Input
    case "$menu2Input" in
        1 ) wgcfmode=0 && install_wgcf ;;
        2 ) wgcfmode=1 && install_wgcf ;;
        3 ) wgcfmode=2 && install_wgcf ;;
        4 ) wgcf_switch ;;
        5 ) uninstall_wgcf ;;
        6 ) install_warpcli ;;
        7 ) change_warpcli_port ;;
        8 ) warpcli_switch ;;
        9 ) uninstall_warpcli ;;
        10 ) install_wireproxy ;;
        11 ) change_wireproxy_port ;;
        12 ) wireproxy_switch ;;
        13 ) uninstall_wireproxy ;;
        14 ) warpup ;;
        15 ) warpsw ;;
        16 ) warpnf ;;
        * ) exit 1 ;;
    esac
}

if [[ $# > 0 ]]; then
    # 暂时没开发、以后再说
    case "$1" in
        * ) menu ;;
    esac
else
    menu
fi