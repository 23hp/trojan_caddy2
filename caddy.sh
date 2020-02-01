#!/bin/ash
# From Dockfile ENV
# WWWSRC="/root/caddy/www"
# Caddy_conf="/root/.config/caddy"
# Trojan_conf="/root/.config/trojan"

your_domain="$1"

echo "====1. 开始校验域名DNS是否绑定VPS IP===="
#校验域名是否绑定部署服务器
if [ -z "$your_domain" ] ; then
  echo "||      缺少域名参数信息！！！"
  exit
else
  real_addr=`ping $your_domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
  local_addr=`curl -s ipv4.icanhazip.com`
  if [ $real_addr != $local_addr ] ; then
    echo "||      域名IP校验失败！"
    exit
  else
    echo "||      通过DNS校验！"
  fi
fi

echo "====2. 开始检测是否安装伪网站===="
#下载伪网站
cd $WWWSRC
if test -s index.html; then
  if test -s web.zip; then
    echo "||      发现新伪网站数据包，更新中..."
    rm -rf `ls | grep -v "^web.zip$"`
    unzip -oq web.zip
    rm -rf web.zip
  fi
else
  wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip
  unzip -oq web.zip
  rm -rf web.zip
fi
echo "||      通过伪网站检测！"

echo "====3. 开始更新Caddy2配置文件===="
#更正Caddy配置文件(绑定域名及网页目录)
cp -f $Caddy_conf/Caddyfile.bak $Caddy_conf/Caddyfile
sed -i "s/domain/$your_domain/; s#wwwdir#$WWWSRC#" $Caddy_conf/Caddyfile
#启动Caddy
nohup caddy run --config $Caddy_conf/Caddyfile > caddy.log &
sleep 1
echo "||      Caddy2参数配置完成并启动！"

echo "====4. 开始检测SSL证书===="
#申请https证书
curl -s -o acme.sh https://get.acme.sh
sed -i "s#curl http#curl -s http#" acme.sh
sh acme.sh > /dev/null
if test -s ~/.acme.sh/$your_domain/fullchain.cer; then
  ~/.acme.sh/acme.sh --cron --home "/root/.acme.sh" --notify-level 1 > /dev/null
  echo "||      $your_domain 已更新SSL证书！"
else
  ~/.acme.sh/acme.sh --issue -d $your_domain --webroot $WWWSRC --notify-level 1
  if test -s ~/.acme.sh/$your_domain/fullchain.cer; then
      echo "||      $your_domain 获得SSL证书成功"
  else
      echo "||      $your_domain 申请错误，请等一小时后再重启"
      exit
  fi
fi
echo "||      通过SSL检测！"

echo "====5. 开始更新Trojan配置文件===="
# 配置trojan参数
cp -f $Trojan_conf/trojan.json $Trojan_conf/config.json
trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
sed -i "s/trojanpsw/$trojan_passwd/" $Trojan_conf/config.json
sed -i "s#trojancrt#$HOME/.acme.sh/$your_domain/fullchain.cer#" $Trojan_conf/config.json
sed -i "s#trojankey#$HOME/.acme.sh/$your_domain/$your_domain.key#" $Trojan_conf/config.json
echo "||      trojan参数配置完成！"

echo "====6. 开始准备Trojan Windows客户端文件===="
# 准备Windows客户端需要文件
trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 5)
mkdir -p $WWWSRC/$trojan_path
cd $WWWSRC/$trojan_path
cp -f ~/.acme.sh/$your_domain/fullchain.cer .
cat > ./config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

zip -q -r trojan-conf.zip *

echo "================================================================================"
echo "||"
echo "||   如果您使用的是Windows，请复制以下链接至浏览器，下载客户端"
echo "||   https://github.com/atrandys/trojan/raw/master/trojan-cli.zip"
echo "||   解压后，再复制以下链接至浏览器，下载更新文件，解压替换客户端文件夹内文件"
echo "||   http://$your_domain/$trojan_path/trojan-conf.zip"
echo "||"
echo "||   如果使用其他系统，请参考以下信息，修改对应客户端配置信息"
echo "||   域名：$your_domain, Trojan passwd: $trojan_passwd"
echo "||"
echo "================================================================================"

#启动Trojan
if [ -z "$2" ]; then
  echo "====恭喜您，Trojan服务器端部署成功！现在您可以通过支持Trojan的客户端开始畅游互联网！===="
  trojan $Trojan_conf/config.json > trojan.log
else
  echo "====测试系统已搭建成功===="
fi
