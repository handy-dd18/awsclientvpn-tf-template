#!/bin/bash
# エラー時にデバッグ情報を表示するようにする
set -e

# ヘルプメッセージ
function show_help {
  echo "使用方法: $0 [オプション]"
  echo ""
  echo "オプション:"
  echo "  -h, --help               このヘルプメッセージを表示"
  echo "  -u, --user <username>    接続するユーザー名を指定（指定がない場合はTerraformから取得）"
  echo "  -i, --ip <ip-address>    接続先IPアドレスを指定（指定がない場合はTerraformから取得）"
  echo ""
  echo "例:"
  echo "  $0                      # Terraformで定義されたユーザーでパスワード認証接続"
  echo "  $0 -u custom-user        # 指定したユーザーでパスワード認証接続"
  echo ""
  echo "注意: このスクリプトを実行する前に、VPN接続が確立されている必要があります。"
  exit 1
}

# デバッグのために追加：コマンドを実行して結果を表示する関数
debug_command() {
  echo "実行コマンド: $1"
  eval "$1"
  local result=$?
  echo "終了コード: $result"
  return $result
}

# デフォルト値
SSH_USER=""
EC2_PRIVATE_IP=""

# 引数の解析
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help) show_help ;;
    -u|--user) SSH_USER="$2"; shift ;;
    -i|--ip) EC2_PRIVATE_IP="$2"; shift ;;
    *) echo "不明なオプション: $1"; show_help ;;
  esac
  shift
done

# Docker環境を検出し、適切なTerraformディレクトリパスを設定
if [ -d "/workspace" ]; then
  # Docker Compose環境でのパス
  TERRAFORM_DIR="/workspace"
elif [ -d "/terraform" ]; then
  # 別の可能性のあるDocker環境でのパス
  TERRAFORM_DIR="/terraform"
else
  # スクリプトのディレクトリから相対パスを試行
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  BASE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  
  if [ -d "${BASE_DIR}/terraform" ]; then
    TERRAFORM_DIR="${BASE_DIR}/terraform"
  else
    echo "エラー: Terraformディレクトリが見つかりません。"
    echo "IPアドレスを -i オプションで明示的に指定してください。"
    exit 1
  fi
fi

echo "Terraformディレクトリを使用: $TERRAFORM_DIR"

# IPアドレスが指定されていない場合、Terraformから取得
if [ -z "$EC2_PRIVATE_IP" ]; then
  cd "$TERRAFORM_DIR"
  
  # Terraformの状態からEC2インスタンスのIPアドレスを取得
  echo "EC2情報を取得中..."
  EC2_PRIVATE_IP=$(terraform output -raw instance_private_ip 2>/dev/null || echo "")
  echo "EC2プライベートIP: $EC2_PRIVATE_IP"

  if [ -z "$EC2_PRIVATE_IP" ]; then
    echo "エラー: EC2インスタンスのプライベートIPアドレスが見つかりません。"
    echo "terraform applyが正常に実行されたか確認してください。"
    echo "または、-i オプションでIPアドレスを明示的に指定してください。"
    exit 1
  fi

  # EC2インスタンスのIDを取得（ログ用）
  EC2_INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
  if [ -n "$EC2_INSTANCE_ID" ]; then
    echo "EC2インスタンスID: $EC2_INSTANCE_ID"
  fi

  # ユーザー名が指定されていない場合、Terraformから取得
  if [ -z "$SSH_USER" ]; then
    echo "ユーザー名を取得中..."
    # variables.tfに定義されたec2_test_userの値を取得
    SSH_USER=$(terraform output -raw ec2_test_user 2>/dev/null || echo "")
    if [ -n "$SSH_USER" ]; then
      echo "Terraform出力から取得したユーザー名: $SSH_USER"
    fi

    # 出力変数が定義されていない場合は、terraform.tfvarsから直接読み取る
    if [ -z "$SSH_USER" ]; then
      echo "terraform.tfvarsからユーザー名を探します..."
      # terraform.tfvarsファイルからec2_test_userを探す
      if [ -f "terraform.tfvars" ]; then
        SSH_USER=$(grep -E "^ec2_test_user\s*=" terraform.tfvars 2>/dev/null | sed 's/^ec2_test_user\s*=\s*"\(.*\)"/\1/' | tr -d ' ' | tr -d '\r\n' || echo "")
        echo "terraform.tfvarsから取得したユーザー名: $SSH_USER"
      fi
      
      # variables.tfからデフォルト値を探す
      if [ -z "$SSH_USER" ] && [ -f "variables.tf" ]; then
        echo "variables.tfからデフォルト値を探します..."
        SSH_USER=$(grep -A5 "variable \"ec2_test_user\"" variables.tf 2>/dev/null | grep "default" | sed 's/.*default\s*=\s*"\(.*\)".*/\1/' | tr -d ' ' || echo "")
        echo "variables.tfから取得したユーザー名: $SSH_USER"
      fi
    fi
  fi
fi

# それでも取得できない場合はデフォルト値を使用
if [ -z "$SSH_USER" ]; then
  SSH_USER="ec2-user"
  echo "警告: テストユーザー名を取得できませんでした。デフォルト値「${SSH_USER}」を使用します。"
fi

# VPN接続確認
echo "VPN接続のpingテスト中..."
if ping -c 1 -W 2 $EC2_PRIVATE_IP > /dev/null 2>&1; then
  echo "VPN接続は正常です。EC2インスタンスに到達可能です。"
else
  echo "警告: EC2インスタンスにpingできません。VPN接続が確立されていることを確認してください。"
  read -p "それでも接続を試みますか？ (y/n): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "接続をキャンセルしました。"
    exit 1
  fi
fi

# VPN接続とEC2インスタンスの情報を表示
echo "-----------------------------------------------------"
echo "EC2インスタンスのプライベートIPアドレス: $EC2_PRIVATE_IP"
echo "EC2インスタンスのプライベートDNS: $(terraform output -raw instance_private_dns 2>/dev/null || echo "不明")"
echo "接続ユーザー: $SSH_USER"
echo "-----------------------------------------------------"

# SSHコマンドを表示
echo ""
echo "以下のコマンドをコピーして別途実行してください:"
echo "-----------------------------------------------------"
echo "ssh -o StrictHostKeyChecking=no ${SSH_USER}@${EC2_PRIVATE_IP}"
echo "-----------------------------------------------------"
echo ""

# 処理完了
echo "スクリプトの実行が完了しました。上記のSSHコマンドを使用して接続してください。"
echo "パスワードはterraform apply時に指定したものを使用してください。"