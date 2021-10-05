#!/bin/bash
# shadowsocksR/SSR一键安装教程
# Author: hijk<https://hijk.art>


RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'


FILENAME="ShadowsocksR-v3.2.2"
URL="https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz"
BASE=`pwd`

OS=`hostnamectl | grep -i system | cut -d: -f2`

CONFIG_FILE="/etc/shadowsocks-r/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks-r.service"
NAME="shadowsocks-r"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}


checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        colorEcho $RED " 请以root身份执行该脚本/use root to run"
        exit 1
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统/system not supported"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update && apt upgrade -y; apt autoremove -y"
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    fi
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本/system low, please upgrade to latest"
        exit 1
    fi
}


status() {
    res=`which python 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1          
    else
        echo 3
    fi
}

statusText() {
    res=`status`
    case $res in
        
        3)
            echo -e ${GREEN}已安装/installed${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装/not installed${PLAIN}
            ;;
    esac
}

preinstall() {
    $PMT clean all
    [[ "$PMT" = "apt" ]] && $PMT update
    #echo $CMD_UPGRADE | bash
    echo ""
    colorEcho $BLUE " 安装必要软件/installing depends"
    if [[ "$PMT" = "yum" ]]; then
        $CMD_INSTALL epel-release
    fi
    $CMD_INSTALL curl wget vim net-tools libsodium* openssl unzip tar qrencode
    res=`which wget 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL wget
    res=`which netstat 2>/dev/null`
    [[ "$?" != "0" ]] && $CMD_INSTALL net-tools
    res=`which python 2>/dev/null`
    ln -s /usr/bin/python3 /usr/bin/python
    
    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

installSSR() {
    if [[ ! -d /usr/local/shadowsocks ]]; then
        colorEcho $BLUE " 下载安装文件/downloading"
        if ! wget --no-check-certificate -O ${FILENAME}.tar.gz ${URL}; then
            echo -e " [${RED}Error${PLAIN}] 下载文件失败/download failed!"
            exit 1
        fi

        tar -zxf ${FILENAME}.tar.gz
        mv shadowsocksr-3.2.2/shadowsocks /usr/local
        if [[ ! -f /usr/local/shadowsocks/server.py ]]; then
            colorEcho $RED " $OS 安装失败，请到 https://hijk.art 网站反馈"
            cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
            exit 1
        fi
        cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
    fi

cat > $SERVICE_FILE <<-EOF
[Unit]
Description=shadowsocks-r
Documentation=https://hijk.art/
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
LimitNOFILE=65535
ExecStart=/usr/local/shadowsocks/server.py -c $CONFIG_FILE -d start
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks-r
}

install() {
    preinstall
    installSSR
}


uninstall() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！/SSR not installed${PLAIN}"
        return
    fi

    echo ""
    read -p " 确定卸载SSR吗/sure to uninstall？(y/n)" answer
    [[ -z ${answer} ]] && answer="n"

    if [[ "${answer}" == "y" ]] || [[ "${answer}" == "Y" ]]; then
        rm -f $CONFIG_FILE
        rm -f /var/log/shadowsocksr.log
        rm -rf /usr/local/shadowsocks
        systemctl disable shadowsocks-r && systemctl stop shadowsocks-r && rm -rf $SERVICE_FILE
    fi
    echo -e " ${RED}卸载成功/uninstall succesfully${PLAIN}"
}
menu() {
    echo -e "  ${GREEN}1.${PLAIN}  安装SSR /install SSR"
    echo -e "  ${GREEN}2.  ${RED}卸载SSR/uninstall SSR${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    echo 
    echo -n " 当前状态/present status："
    statusText
    echo 

    read -p " 请选择操作/please select[0-2]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            install
            ;;
        2)
            uninstall
            ;;
            
        *)
            echo -e "$RED 请选择正确的操作！${PLAIN}"
            exit 1
            ;;
    esac
}

checkSystem

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
    menu|install|uninstall)
        ${action}
        ;;
    *)
        echo " 参数错误"
        echo " 用法: `basename $0` [menu|install|uninstall|start|restart|stop]"
        ;;
esac
