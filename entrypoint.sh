#!/usr/bin/env bash

# 设置各变量
APIHOST=${APIHOST}
APIKEY=${APIKEY}
NID=${NID}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 安装系统依赖
check_dependencies() {
  DEPS_CHECK=("wget" "unzip")
  DEPS_INSTALL=(" wget" " unzip")
  for ((i=0;i<${#DEPS_CHECK[@]};i++)); do [[ ! $(type -p ${DEPS_CHECK[i]}) ]] && DEPS+=${DEPS_INSTALL[i]}; done
  [ -n "$DEPS" ] && { apt-get update >/dev/null 2>&1; apt-get install -y $DEPS >/dev/null 2>&1; }
}

generate_config() {
  cat > config.yml << EOF
Log:
  Level: none
  AccessPath:
  ErrorPath:
DnsConfigPath:
ConnetionConfig:
  Handshake: 4
  ConnIdle: 10
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  -
    PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "${APIHOST}"
      ApiKey: "${APIKEY}"
      NodeID: ${NID}
      NodeType: V2ray
      Timeout: 30
      EnableVless: false
      EnableXTLS: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      CertConfig:
        CertMode: none
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash  
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -e cloudflared && ! \$(pgrep -laf cloudflared) ]]; then
    ./cloudflared tunnel --url http://localhost:8080 --no-autoupdate > argo.log 2>&1 &
    sleep 10
    ARGO=\$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")
    cat > list << EOF
*******************************************
NID  ==> ${NID}
ARGO ==> \${ARGO}
NID  ==> ${NID}
*******************************************
EOF
    cat list
  fi
}

check_file
run
wait
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf nezha-agent) ]] && echo "哪吒客户端正在运行中" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY}
}

check_run
check_variable
download_agent
run
wait
EOF
}

check_dependencies
generate_config
generate_argo
generate_nezha
[ -e nezha.sh ] && bash nezha.sh 2>&1 &
[ -e argo.sh ] && bash argo.sh 2>&1 &
wait