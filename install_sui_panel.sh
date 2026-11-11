#!/usr/bin/env bash
set -Eeuo pipefail

SUI_VERSION="${SUI_VERSION:-v1.4.1}"
SUI_INSTALL_URL="https://raw.githubusercontent.com/alireza0/s-ui/${SUI_VERSION}/install.sh"
DEFAULT_PANEL_PORT="${DEFAULT_PANEL_PORT:-2095}"
DEFAULT_SSH_USER="${DEFAULT_SSH_USER:-root}"
DEFAULT_SSH_HOST="${DEFAULT_SSH_HOST:-YOUR_VPS_IP}"
DEFAULT_TIMEOUT_SECONDS="${DEFAULT_TIMEOUT_SECONDS:-1}"

REALITY_DOMAINS=(
  ts2.tc.mm.bing.net
  assets-www.xbox.com
  res.cdn.office.net
  aadcdn.msftauth.net
  d2c.aws.amazon.com
  vs.aws.amazon.com
  a0.awsstatic.com
  docs.aws.amazon.com
  static.licdn.com
  snap.licdn.com
  media.licdn.com
  www.gstatic.com
  fonts.gstatic.com
  lh3.googleusercontent.com
  static.doubleclick.net
  scontent.xx.fbcdn.net
  static.xx.fbcdn.net
  i.ytimg.com
  c.apple.com
  m.stripe.com
  api.github.com
  cdn.shopify.com
  images-na.ssl-images-amazon.com
  s.yimg.com
  discord.com
)

need_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "缺少命令：$command_name"
    echo "请先安装它，或换一台系统更完整的 VPS 再运行。"
    exit 1
  fi
}

pause_for_enter() {
  echo
  read -r -p "按回车返回菜单..." _
}

read_with_default() {
  local prompt="$1"
  local default_value="$2"
  local value

  read -r -p "${prompt} [默认：${default_value}]: " value
  echo "${value:-$default_value}"
}

install_sui_panel() {
  need_command curl
  need_command bash

  echo
  echo "即将安装 S-UI 面板，版本：${SUI_VERSION}"
  echo "安装脚本来源：${SUI_INSTALL_URL}"
  echo
  echo "风险提示：这会从 GitHub 下载并执行安装脚本，可能会修改 VPS 的服务、端口和系统配置。"
  read -r -p "确认在这台 VPS 上安装吗？输入 YES 继续: " confirm

  if [[ "$confirm" != "YES" ]]; then
    echo "已取消安装。"
    return 0
  fi

  VERSION="$SUI_VERSION" bash <(curl -Ls "$SUI_INSTALL_URL") "$SUI_VERSION"
}

build_ssh_tunnel_command() {
  local ssh_user
  local ssh_host
  local panel_port

  echo
  ssh_user="$(read_with_default "请输入 SSH 用户" "$DEFAULT_SSH_USER")"
  ssh_host="$(read_with_default "请输入 VPS IP 或域名" "$DEFAULT_SSH_HOST")"
  panel_port="$(read_with_default "请输入 S-UI 面板端口" "$DEFAULT_PANEL_PORT")"

  echo
  echo "在你自己的电脑终端运行下面这条命令："
  echo
  echo "ssh -L ${panel_port}:127.0.0.1:${panel_port} ${ssh_user}@${ssh_host}"
  echo
  echo "成功标志：SSH 连接保持不断开，然后浏览器打开 http://127.0.0.1:${panel_port}"
}

now_ms() {
  local value

  value="$(date +%s%3N 2>/dev/null || true)"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$value"
  else
    echo "$(($(date +%s) * 1000))"
  fi
}

test_reality_domains() {
  need_command openssl
  need_command timeout

  local timeout_seconds="$DEFAULT_TIMEOUT_SECONDS"
  local domain
  local started_at
  local ended_at

  echo
  echo "开始检测 Reality 目标域名，超时时间：${timeout_seconds} 秒"
  echo "建议优先选延迟低、成功率高、看起来稳定的大站域名。"
  echo

  for domain in "${REALITY_DOMAINS[@]}"; do
    started_at="$(now_ms)"
    if timeout "$timeout_seconds" openssl s_client -tls1_3 -connect "${domain}:443" -servername "$domain" </dev/null >/dev/null 2>&1; then
      ended_at="$(now_ms)"
      echo "${domain}: $((ended_at - started_at)) ms"
    else
      echo "${domain}: timeout/fail"
    fi
  done
}

run_all() {
  test_reality_domains
  echo
  read -r -p "是否继续安装 S-UI 面板？输入 YES 继续: " confirm_install

  if [[ "$confirm_install" == "YES" ]]; then
    install_sui_panel
  else
    echo "已跳过安装。"
  fi

  build_ssh_tunnel_command
}

print_menu() {
  clear 2>/dev/null || true
  echo "S-UI VPS 辅助脚本"
  echo "版本：${SUI_VERSION}"
  echo
  echo "1) 安装 S-UI 面板"
  echo "2) 生成 SSH 本地转发命令"
  echo "3) Reality 目标域名检测"
  echo "4) 一键流程：测速 -> 可选安装 -> 生成连接命令"
  echo "0) 退出"
  echo
}

main() {
  local choice

  while true; do
    print_menu
    read -r -p "请选择: " choice

    case "$choice" in
      1)
        install_sui_panel
        pause_for_enter
        ;;
      2)
        build_ssh_tunnel_command
        pause_for_enter
        ;;
      3)
        test_reality_domains
        pause_for_enter
        ;;
      4)
        run_all
        pause_for_enter
        ;;
      0)
        echo "已退出。"
        exit 0
        ;;
      *)
        echo "无效选择，请输入 0-4。"
        sleep 1
        ;;
    esac
  done
}

main "$@"
