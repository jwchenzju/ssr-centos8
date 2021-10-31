#!/bin/bash
#安装必要的SSR文件和服务，不带配置

FILENAME="ShadowsocksR-v3.2.2"
URL="https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz"
BASE=`pwd`

CONFIG_FILE="/etc/shadowsocks-r/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks-r.service"
NAME="shadowsocks-r"

preinstall() {
    yum -y install python3 wget tar
    ln -s /usr/bin/python3 /usr/bin/python
    
    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

installSSR() {
    wget --no-check-certificate -O ${FILENAME}.tar.gz ${URL}
    tar -zxf ${FILENAME}.tar.gz
    mv shadowsocksr-3.2.2/shadowsocks /usr/local
       
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

menu() {
    echo -e "  ${GREEN}1.${PLAIN}  安装SSR /install SSR"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    
    read -p " 请选择操作/please select[0-2]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            install
            ;;                   
        *)
            echo -e "$RED 请选择正确的操作！${PLAIN}"
            exit 1
            ;;
    esac
}

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
    menu|install|uninstall)
        ${action}
        ;;
    *)
        echo " 参数错误"
        echo " 用法: `basename $0` [menu|install]"
        ;;
esac
