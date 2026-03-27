#!/usr/bin/env bash
# ===== Ubuntu Server Initializer =====
# config.yaml을 읽어서 서버를 자동 세팅합니다.
# 사용법: sudo ./setup.sh [config.yaml 경로]
#
set -euo pipefail

# ===== 색상 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

CONFIG="${1:-config.yaml}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/ubuntu-init-$(date +%Y%m%d-%H%M%S).log"

# ===== 유틸리티 함수 =====
log()    { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
ok()     { echo -e "${GREEN}  ✅ $*${NC}" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}  ⚠️  $*${NC}" | tee -a "$LOG_FILE"; }
error()  { echo -e "${RED}  ❌ $*${NC}" | tee -a "$LOG_FILE"; }
header() { echo -e "\n${BOLD}━━━ $* ━━━${NC}" | tee -a "$LOG_FILE"; }

# ===== 사전 확인 =====
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "sudo로 실행해야 합니다: sudo $0"
        exit 1
    fi
}

check_python() {
    if ! command -v python3 &>/dev/null; then
        log "Python3 설치 중..."
        apt-get update -qq && apt-get install -y -qq python3
    fi
    ok "Python3 확인: $(python3 --version)"
}

check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "설정 파일 없음: $CONFIG"
        echo "  예시: cp config.example.yaml config.yaml"
        exit 1
    fi
    ok "설정 파일 확인: $CONFIG"
}

# ===== YAML 파서 (Python3 사용) =====
yaml_get() {
    local key="$1"
    python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
keys = '$key'.split('.')
for k in keys:
    if isinstance(data, dict):
        data = data.get(k, {})
    elif isinstance(data, list) and isinstance(k, int):
        data = data[k] if k < len(data) else {}
    else:
        data = {}
        break
if data is None:
    print('')
elif isinstance(data, list):
    print('\n'.join(str(i) for i in data))
elif isinstance(data, dict):
    print('\n'.join(f'{k}={v}' for k, v in data.items()))
else:
    print(data)
" 2>/dev/null
}

yaml_list_len() {
    local key="$1"
    python3 -c "
import yaml
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
keys = '$key'.split('.')
for k in keys:
    data = data.get(k, []) if isinstance(data, dict) else []
print(len(data) if isinstance(data, list) else 0)
" 2>/dev/null
}

yaml_get_index() {
    local key="$1"
    local idx="$2"
    local subkey="$3"
    python3 -c "
import yaml
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
keys = '$key'.split('.')
for k in keys:
    data = data.get(k, []) if isinstance(data, dict) else []
if isinstance(data, list) and $idx < len(data):
    item = data[$idx]
    if isinstance(item, dict):
        print(item.get('$subkey', ''))
    else:
        print(item)
else:
    print('')
" 2>/dev/null
}

# ===== 1. 호스트명 설정 =====
setup_hostname() {
    header "1/12 호스트명 설정"
    local hostname
    hostname=$(yaml_get "server.hostname")
    if [[ -n "$hostname" ]]; then
        hostnamectl set-hostname "$hostname"
        echo "127.0.1.1 $hostname" >> /etc/hosts
        ok "호스트명: $hostname"
    else
        warn "호스트명 미설정 (스킵)"
    fi
}

# ===== 2. 타임존 설정 =====
setup_timezone() {
    header "2/12 타임존 설정"
    local tz
    tz=$(yaml_get "server.timezone")
    if [[ -n "$tz" ]]; then
        timedatectl set-timezone "$tz" 2>/dev/null || ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
        ok "타임존: $tz"
    else
        warn "타임존 미설정 (스킵)"
    fi
}

# ===== 3. apt 패키지 설치 =====
install_apt_packages() {
    header "3/12 APT 패키지 설치"
    local count
    count=$(yaml_list_len "packages.apt")
    
    if [[ "$count" -eq 0 ]]; then
        warn "설치할 APT 패키지 없음 (스킵)"
        return
    fi
    
    log "업데이트 중..."
    apt-get update -qq
    
    local packages=()
    for ((i=0; i<count; i++)); do
        local pkg
        pkg=$(yaml_get_index "packages.apt" "$i" "")
        if [[ -n "$pkg" ]]; then
            packages+=("$pkg")
        fi
    done
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        log "설치: ${packages[*]}"
        apt-get install -y -qq "${packages[@]}" >> "$LOG_FILE" 2>&1
        ok "${#packages[@]}개 패키지 설치 완료"
    fi
}

# ===== 4. snap 패키지 설치 =====
install_snap_packages() {
    header "4/12 SNAP 패키지 설치"
    local count
    count=$(yaml_list_len "packages.snap")
    
    if [[ "$count" -eq 0 ]]; then
        warn "설치할 SNAP 패키지 없음 (스킵)"
        return
    fi
    
    if ! command -v snap &>/dev/null; then
        warn "snap 미설치 (스킵)"
        return
    fi
    
    for ((i=0; i<count; i++)); do
        local name classic
        name=$(yaml_get_index "packages.snap" "$i" "name")
        classic=$(yaml_get_index "packages.snap" "$i" "classic")
        
        if [[ -n "$name" ]]; then
            local flags=""
            [[ "$classic" == "True" ]] && flags="--classic"
            log "snap 설치: $name $flags"
            snap install "$name" $flags >> "$LOG_FILE" 2>&1 || warn "snap $name 설치 실패"
            ok "snap: $name"
        fi
    done
}

# ===== 5. pip 패키지 설치 =====
install_pip_packages() {
    header "5/12 PIP 패키지 설치"
    local count
    count=$(yaml_list_len "packages.pip")
    
    if [[ "$count" -eq 0 ]]; then
        warn "설치할 PIP 패키지 없음 (스킵)"
        return
    fi
    
    if ! command -v pip3 &>/dev/null; then
        log "pip3 설치 중..."
        apt-get install -y -qq python3-pip >> "$LOG_FILE" 2>&1
    fi
    
    local packages=()
    for ((i=0; i<count; i++)); do
        local pkg
        pkg=$(yaml_get_index "packages.pip" "$i" "")
        [[ -n "$pkg" ]] && packages+=("$pkg")
    done
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        log "pip 설치: ${packages[*]}"
        pip3 install -q "${packages[@]}" >> "$LOG_FILE" 2>&1
        ok "${#packages[@]}개 pip 패키지 설치 완료"
    fi
}

# ===== 6. 서비스 설정 =====
setup_services() {
    header "6/12 서비스 설정"
    
    # enable
    local enable_count
    enable_count=$(yaml_list_len "services.enable")
    for ((i=0; i<enable_count; i++)); do
        local svc
        svc=$(yaml_get_index "services.enable" "$i" "")
        if [[ -n "$svc" ]]; then
            systemctl enable "$svc" >> "$LOG_FILE" 2>&1 && ok "서비스 활성화: $svc"
        fi
    done
    
    # start
    local start_count
    start_count=$(yaml_list_len "services.start")
    for ((i=0; i<start_count; i++)); do
        local svc
        svc=$(yaml_get_index "services.start" "$i" "")
        if [[ -n "$svc" ]]; then
            systemctl start "$svc" >> "$LOG_FILE" 2>&1 && ok "서비스 시작: $svc"
        fi
    done
    
    [[ $enable_count -eq 0 && $start_count -eq 0 ]] && warn "설정된 서비스 없음 (스킵)"
}

# ===== 7. 방화벽 설정 =====
setup_firewall() {
    header "7/12 방화벽 (UFW) 설정"
    
    if ! command -v ufw &>/dev/null; then
        warn "ufw 미설치 (스킵)"
        return
    fi
    
    # 기본 정책
    local input_rule output_rule
    input_rule=$(yaml_get "firewall.default_input")
    output_rule=$(yaml_get "firewall.default_output")
    
    [[ -n "$input_rule" ]] && ufw default "$input_rule" >> "$LOG_FILE" 2>&1
    [[ -n "$output_rule" ]] && ufw default "$output_rule" >> "$LOG_FILE" 2>&1
    ok "기본 정책: input=$input_rule, output=$output_rule"
    
    # 규칙 추가
    local rule_count
    rule_count=$(yaml_list_len "firewall.rules")
    for ((i=0; i<rule_count; i++)); do
        local port action comment
        port=$(yaml_get_index "firewall.rules" "$i" "port")
        action=$(yaml_get_index "firewall.rules" "$i" "action")
        comment=$(yaml_get_index "firewall.rules" "$i" "comment")
        
        if [[ -n "$port" && -n "$action" ]]; then
            if [[ -n "$comment" ]]; then
                ufw allow "$port" comment "$comment" >> "$LOG_FILE" 2>&1
            else
                ufw allow "$port" >> "$LOG_FILE" 2>&1
            fi
            ok "방화벽: $action $port ($comment)"
        fi
    done
    
    # UFW 활성화 (--force)
    echo "y" | ufw enable >> "$LOG_FILE" 2>&1
    ok "UFW 활성화 완료"
    
    [[ $rule_count -eq 0 ]] && warn "설정된 방화벽 규칙 없음"
}

# ===== 8. 사용자 생성 =====
setup_users() {
    header "8/12 사용자 생성"
    local count
    count=$(yaml_list_len "users")
    
    if [[ "$count" -eq 0 ]]; then
        warn "생성할 사용자 없음 (스킵)"
        return
    fi
    
    for ((i=0; i<count; i++)); do
        local name shell groups ssh_key password
        name=$(yaml_get_index "users" "$i" "name")
        shell=$(yaml_get_index "users" "$i" "shell")
        groups=$(yaml_get_index "users" "$i" "groups")
        ssh_key=$(yaml_get_index "users" "$i" "ssh_key")
        password=$(yaml_get_index "users" "$i" "password")
        
        [[ -z "$shell" ]] && shell="/bin/bash"
        
        if [[ -n "$name" ]]; then
            # 사용자 생성
            if id "$name" &>/dev/null; then
                warn "사용자 이미 존재: $name"
            else
                useradd -m -s "$shell" "$name"
                ok "사용자 생성: $name"
            fi
            
            # 그룹 추가
            if [[ -n "$groups" ]]; then
                IFS=',' read -ra group_arr <<< "$groups"
                for grp in "${group_arr[@]}"; do
                    grp=$(echo "$grp" | xargs)  # trim
                    groupadd "$grp" 2>/dev/null || true
                    usermod -aG "$grp" "$name" 2>/dev/null && ok "  그룹 추가: $grp"
                done
            fi
            
            # SSH 키
            if [[ -n "$ssh_key" ]]; then
                mkdir -p /home/"$name"/.ssh
                echo "$ssh_key" >> /home/"$name"/.ssh/authorized_keys
                chown -R "$name":"$name" /home/"$name"/.ssh
                chmod 700 /home/"$name"/.ssh
                chmod 600 /home/"$name"/.ssh/authorized_keys
                ok "SSH 키 설정"
            fi
            
            # 비밀번호
            if [[ -n "$password" ]]; then
                echo "$name:$password" | chpasswd
            elif [[ -z "$ssh_key" ]]; then
                # 비밀번호와 SSH 키 둘 다 없으면 무작위 생성
                local rand_pass
                rand_pass=$(openssl rand -base64 12)
                echo "$name:$rand_pass" | chpasswd
                warn "  임시 비밀번호: $rand_pass (기록해두세요!)"
            fi
        fi
    done
}

# ===== 9. 디렉토리 생성 =====
setup_directories() {
    header "9/12 디렉토리 생성"
    local count
    count=$(yaml_list_len "directories")
    
    if [[ "$count" -eq 0 ]]; then
        warn "생성할 디렉토리 없음 (스킵)"
        return
    fi
    
    for ((i=0; i<count; i++)); do
        local path owner mode
        path=$(yaml_get_index "directories" "$i" "path")
        owner=$(yaml_get_index "directories" "$i" "owner")
        mode=$(yaml_get_index "directories" "$i" "mode")
        
        if [[ -n "$path" ]]; then
            mkdir -p "$path"
            [[ -n "$owner" ]] && chown "$owner" "$path"
            [[ -n "$mode" ]] && chmod "$mode" "$path"
            ok "디렉토리: $path"
        fi
    done
}

# ===== 10. 설정 파일 작성 =====
setup_files() {
    header "10/12 설정 파일 작성"
    local count
    count=$(yaml_list_len "files")
    
    if [[ "$count" -eq 0 ]]; then
        warn "작성할 파일 없음 (스킵)"
        return
    fi
    
    for ((i=0; i<count; i++)); do
        local path content owner mode
        path=$(yaml_get_index "files" "$i" "path")
        owner=$(yaml_get_index "files" "$i" "owner")
        mode=$(yaml_get_index "files" "$i" "mode")
        content=$(yaml_get_index "files" "$i" "content")
        
        if [[ -n "$path" && -n "$content" ]]; then
            mkdir -p "$(dirname "$path")"
            echo "$content" > "$path"
            [[ -n "$owner" ]] && chown "$owner" "$path"
            [[ -n "$mode" ]] && chmod "$mode" "$path"
            ok "파일 작성: $path"
        fi
    done
}

# ===== 11. 후처리 커맨드 =====
run_commands() {
    header "11/12 후처리 커맨드 실행"
    local count
    count=$(yaml_list_len "commands")
    
    if [[ "$count" -eq 0 ]]; then
        warn "실행할 커맨드 없음 (스킵)"
        return
    fi
    
    for ((i=0; i<count; i++)); do
        local cmd
        cmd=$(yaml_get_index "commands" "$i" "")
        if [[ -n "$cmd" ]]; then
            log "실행: $cmd"
            eval "$cmd" >> "$LOG_FILE" 2>&1
            ok "완료: $cmd"
        fi
    done
}

# ===== 0. 시스템 업데이트 =====
system_update() {
    header "0/12 시스템 업데이트"
    log "apt update 실행 중..."
    apt-get update -qq >> "$LOG_FILE" 2>&1
    ok "apt update 완료"
    log "apt upgrade 실행 중..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
    ok "apt upgrade 완료"
}

# ===== 메인 실행 =====
main() {
    clear
    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║     🐧 Ubuntu Server Initializer        ║"
    echo "║     config.yaml → 자동 서버 세팅         ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    log "설정 파일: $CONFIG"
    log "로그 파일: $LOG_FILE"

    check_root
    check_python
    check_config

    system_update
    setup_hostname
    setup_timezone
    install_apt_packages
    install_snap_packages
    install_pip_packages
    setup_services
    setup_firewall
    setup_users
    setup_directories
    setup_files
    run_commands
    
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          ✅ 초기화 완료!                  ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    log "로그 파일: $LOG_FILE"
}

main "$@"
